import XCTest

/// Every screen, from a fresh install, in one variant: DESIGN_VARIANT is
/// "day", "night", or "xxxl" (day at the largest accessibility text size).
@MainActor
final class ScreenTourTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTour() {
        let app = XCUIApplication()
        app.launchArguments = Self.launchArguments
        app.launch()

        // Onboarding
        XCTAssertTrue(app.buttons["Add your child"].waitForExistence(timeout: 10))
        sleep(1)
        Capture.screen("01-onboarding-welcome")
        tapButton(app, "Add your child")
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Cal")
        Capture.screen("02-onboarding-add-child")
        tapButton(app, "Continue")
        sleep(1)
        Capture.screen("03-onboarding-care-plan")
        tapButton(app, "Skip for now")
        sleep(1)
        Capture.screen("04-onboarding-reminders")
        tapButton(app, "Skip for now")
        sleep(1)
        Capture.screen("05-onboarding-log-anywhere")
        tapButton(app, "Skip for now")
        sleep(1)
        Capture.screen("07-today-empty")

        // First log: the confirmation, then the one-time reminders offer.
        tapButton(app, "Log itching")
        Capture.screen("08-log-confirmation")
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 8) {
            sleep(1)
            Capture.screen("09-reminder-offer")
            notNow.tap()
        }
        tapButton(app, "Log a bowel movement")
        tapButton(app, "Log a good night")
        tapButton(app, "Log itching")
        sleep(5)  // let the confirmation leave
        app.swipeDown()
        Capture.screen("10-today")
        app.swipeUp()
        Capture.screen("11-today-scrolled")
        app.swipeUp()
        Capture.screen("12-today-week")

        // Edit a log
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS ' AM' OR label CONTAINS ' PM'")).firstMatch
        if row.waitForExistence(timeout: 3) {
            row.tap()
            sleep(1)
            Capture.screen("13-edit-log")
            tapButton(app, "Cancel")
        }

        // Settings, the debug list, and the setup guide
        app.swipeDown()
        app.swipeDown()
        tapButton(app, "Settings")
        Capture.screen("14-settings")
        app.swipeUp()
        Capture.screen("15-settings-scrolled")
        tapButton(app, "Recent logs")
        Capture.screen("16-recent-logs-debug-list")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        tapButton(app, "Home Screen widget")
        Capture.screen("17-quick-logging-guide")
    }

    private func tapButton(_ app: XCUIApplication, _ label: String) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No button \(label)")
        button.tap()
        sleep(1)
    }

    static var variant: String {
        ProcessInfo.processInfo.environment["DESIGN_VARIANT"] ?? "day"
    }

    static var launchArguments: [String] {
        switch variant {
        case "night":
            ["-designReviewNight", "YES"]
        case "xxxl":
            ["-designReviewNight", "NO",
             "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        default:
            ["-designReviewNight", "NO"]
        }
    }
}

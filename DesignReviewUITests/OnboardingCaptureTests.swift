import XCTest

/// Onboarding and every setup guide screen, from a fresh install.
/// Same DESIGN_VARIANT and DESIGN_OUT as the screen tour; run on an erased simulator.
@MainActor
final class OnboardingCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private var variant: String { ScreenTourTests.variant }

    func testOnboardingAndGuides() {
        let app = XCUIApplication()
        // Day allows notifications and night says no, so both outcomes are captured.
        app.launchArguments = ScreenTourTests.launchArguments
            + ["-designReviewNotifications", variant == "night" ? "deny" : "allow"]
        app.launch()

        sleep(2)
        Capture.screen("onb-1-welcome-\(variant)")
        tap(app.buttons["Add your child"])

        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Cal")
        Capture.screen("onb-2-child-\(variant)")
        // Put the keyboard (and a fresh simulator's typing tip) away to show the Color row.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.94)).tap()
        sleep(1)
        app.swipeDown()
        sleep(1)
        Capture.screen("onb-2-child-color-\(variant)")
        // A fresh simulator can show a keyboard tip with its own "Continue".
        let plan = app.staticTexts["Bring in your care plan"]
        for _ in 0..<5 where !plan.exists {
            app.buttons["Continue"].firstMatch.tap()
            sleep(1)
        }
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        Capture.screen("onb-3-plan-\(variant)")
        tap(app.buttons["Skip for now"])

        let reminders = app.staticTexts["Gentle reminders"]
        XCTAssertTrue(reminders.waitForExistence(timeout: 5))

        Capture.screen("onb-4-reminders-\(variant)")
        app.switches.firstMatch.tap()
        sleep(3)
        Capture.screen("onb-4-reminders-on-\(variant)")
        tap(app.buttons["Skip for now"])

        Capture.screen("onb-5-log-lock-\(variant)")
        tap(app.buttons["Home Screen"])
        Capture.screen("onb-5-log-home-\(variant)")
        tap(app.buttons["Control Center"])
        Capture.screen("onb-5-log-cc-\(variant)")

        for (segment, key, button, count) in [
            ("Lock Screen", "lock", "Add it to my Lock Screen", 6),
            ("Home Screen", "home", "Add it to my Home Screen", 6),
            ("Control Center", "cc", "Add it to Control Center", 5),
        ] {
            tap(app.buttons[segment])
            tap(app.buttons[button])
            for step in 1...count {
                Capture.screen("guide-\(key)-\(step)-\(variant)")
                tap(app.buttons["Next"])
            }
            Capture.screen("guide-\(key)-done-\(variant)")
            if key == "lock" {
                tap(app.buttons["Remind me later"])
                sleep(1)
                Capture.screen("guide-lock-reminded-\(variant)")
            }
            tap(app.buttons["Done"])
        }

        tap(app.buttons["Go to Today"])
        sleep(2)
        Capture.screen("onb-6-today-\(variant)")
    }

    /// Today the morning after a night with wake-ups that isn't rated yet.
    func testTodayUnrated() {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "UNRATED"]
        app.launch()
        sleep(4)
        Capture.screen("today-unrated-\(variant)")
    }

    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        element.tap()
        sleep(1)
    }
}

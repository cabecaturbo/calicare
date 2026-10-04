import XCTest

/// U1: each tab and the Settings sheet, from a fresh install with a few logs.
/// Same DESIGN_VARIANT and DESIGN_OUT as the screen tour.
@MainActor
final class ShellTourTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testShell() {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments
        app.launch()

        // Onboarding, skipping every guide.
        tap(app.buttons["Add your child"])
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Cal")
        // A fresh simulator can show a keyboard tip with its own "Continue".
        for _ in 0..<3 where name.exists {
            app.buttons["Continue"].firstMatch.tap()
            sleep(1)
        }
        tap(app.buttons["Skip for now"])  // reminders
        tap(app.buttons["Skip for now"])  // log from anywhere

        // A few logs so the tabs have something in them.
        tap(app.buttons["Log itching"])
        if app.buttons["Not now"].waitForExistence(timeout: 8) {
            app.buttons["Not now"].tap()
            sleep(1)
        }
        tap(app.buttons["Log a good night"])
        tap(app.buttons["Log a bowel movement"])
        sleep(5)  // let the confirmation leave
        Capture.screen("01-today")

        tap(app.tabBars.buttons["To do"])
        tap(app.buttons["Log morning routine done"])
        sleep(5)
        Capture.screen("02-plan")

        tap(app.buttons["Log something else"])
        Capture.screen("03-log-sheet")
        tap(app.buttons["Cancel"])

        tap(app.tabBars.buttons["How it’s going"])
        sleep(2)
        Capture.screen("04-progress")

        tap(app.navigationBars.buttons["Settings"])
        Capture.screen("05-settings")
        app.swipeUp()
        sleep(1)
        Capture.screen("06-settings-scrolled")
        app.swipeUp()
        sleep(1)
        Capture.screen("07-settings-end")
    }

    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        element.tap()
        sleep(1)
    }
}

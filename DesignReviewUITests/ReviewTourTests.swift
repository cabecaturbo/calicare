import XCTest

/// The review pass: each tab with two children (one with a long name), the
/// child switcher, and Settings. Run with DESIGN_VARIANT day, night, and xxxl.
@MainActor
final class ReviewTourTests: XCTestCase {
    func testTabsWithTwoChildren() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "TWO"]
        app.launch()
        sleep(3)

        Capture.screen("review-today-\(variant)")
        app.swipeUp()
        sleep(1)
        Capture.screen("review-today-scrolled-\(variant)")
        app.swipeDown()

        let switcher = app.buttons["Cal"].firstMatch
        if switcher.waitForExistence(timeout: 3) {
            switcher.tap()
            sleep(1)
            Capture.screen("review-switcher-\(variant)")
            if app.buttons["Maximiliana-Josephine"].exists {
                app.buttons["Maximiliana-Josephine"].tap()
                sleep(2)
                Capture.screen("review-today-second-child-\(variant)")
            } else {
                app.tap()
            }
        }

        for tab in ["To do", "Progress", "Plan"] {
            app.buttons[tab].tap()
            sleep(2)
            Capture.screen("review-\(tab.lowercased())-\(variant)")
        }
        app.buttons["Settings"].firstMatch.tap()
        sleep(1)
        Capture.screen("review-settings-\(variant)")
    }
}

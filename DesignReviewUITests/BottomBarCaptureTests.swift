import XCTest

/// The bottom bar options side by side: Today and Plan, and right after an Itchy tap.
@MainActor
final class BottomBarCaptureTests: XCTestCase {
    func testOptions() {
        let variant = ScreenTourTests.variant
        for style in ["pills", "glassRow", "glassCircle"] {
            let app = XCUIApplication()
            app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "YES", "-bottomBarStyle", style]
            app.launch()
            sleep(3)
            Capture.screen("bar-\(style)-today-\(variant)")
            app.buttons["Plan"].firstMatch.tap()
            sleep(2)
            Capture.screen("bar-\(style)-plan-\(variant)")
            let itchy = style == "glassCircle" ? app.buttons["Itchy"].firstMatch : app.buttons["Log itching"].firstMatch
            if itchy.waitForExistence(timeout: 3) {
                itchy.tap()
                sleep(1)
                Capture.screen("bar-\(style)-logged-\(variant)")
            }
            app.terminate()
        }
    }
}

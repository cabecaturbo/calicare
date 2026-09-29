import XCTest

/// The glass tab bar with the round Log button: Today, Plan, and right after a log.
@MainActor
final class BottomBarCaptureTests: XCTestCase {
    func testBar() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "YES"]
        app.launch()
        sleep(3)
        Capture.screen("bar-today-\(variant)")
        app.buttons["More to log"].firstMatch.tap()
        sleep(1)
        Capture.screen("bar-more-\(variant)")
        app.tap()
        app.buttons["Plan"].firstMatch.tap()
        sleep(2)
        app.buttons["Log itching"].firstMatch.tap()
        sleep(1)
        Capture.screen("bar-logged-\(variant)")
    }
}

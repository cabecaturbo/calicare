import XCTest

/// Progress by week and month, with about two months of logs.
/// Same DESIGN_VARIANT and DESIGN_OUT as the screen tour; run on an erased simulator.
@MainActor
final class ProgressCaptureTests: XCTestCase {
    func testWeekAndMonth() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "MONTHS"]
        app.launch()
        sleep(3)

        app.buttons["How it’s going"].tap()
        sleep(2)
        Capture.screen("progress-week-\(variant)")
        app.buttons["Month"].tap()
        sleep(2)
        Capture.screen("progress-month-\(variant)")
        app.swipeUp()
        sleep(1)
        Capture.screen("progress-month-scrolled-\(variant)")
    }
}

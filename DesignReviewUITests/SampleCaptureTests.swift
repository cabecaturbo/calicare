import XCTest

/// Every tab filled with the eight weeks of sample data, with each screen's drawing.
@MainActor
final class SampleCaptureTests: XCTestCase {
    func testLivedIn() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "SAMPLE"]
        app.launch()
        sleep(8) // the seed writes a few hundred logs
        app.terminate()
        app.launch()
        sleep(3)
        Capture.screen("sample-today-\(variant)")
        app.swipeUp()
        sleep(1)
        Capture.screen("sample-today-scrolled-\(variant)")
        app.buttons["To do"].firstMatch.tap()
        sleep(2)
        Capture.screen("sample-plan-\(variant)")
        app.buttons["Progress"].firstMatch.tap()
        sleep(2)
        Capture.screen("sample-week-\(variant)")
        app.buttons["Month"].firstMatch.tap()
        sleep(2)
        Capture.screen("sample-month-\(variant)")
    }
}

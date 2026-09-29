import XCTest

/// Settings › Quick logging › Send the weekly card automatically.
@MainActor
final class AutoSendCaptureTests: XCTestCase {
    func testAutoSendGuide() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "YES"]
        app.launch()
        sleep(3)
        app.buttons["Settings"].firstMatch.tap()
        sleep(1)
        let row = app.buttons["Send the weekly card automatically"]
        for _ in 0..<4 where !row.isHittable { app.swipeUp() }
        row.tap()
        sleep(2)
        Capture.screen("autosend-\(variant)")
    }
}

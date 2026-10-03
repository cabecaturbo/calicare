import XCTest

/// Settings › Your data › Daily journal for your provider, with sample data.
@MainActor
final class JournalCaptureTests: XCTestCase {
    func testJournal() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "SAMPLE"]
        app.launch()
        sleep(8)
        app.buttons["Settings"].firstMatch.tap()
        sleep(1)
        let data = app.buttons["Export and what's stored where"]
        for _ in 0..<4 where !data.isHittable { app.swipeUp() }
        data.tap()
        sleep(1)
        app.buttons["Daily journal for your provider"].firstMatch.tap()
        sleep(4)
        Capture.screen("journal-\(variant)")
    }
}

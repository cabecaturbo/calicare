import XCTest

/// The bottom bar's Log: logs and stays on the tab you were on (never a blank screen).
@MainActor
final class LogTapTests: XCTestCase {
    func testLogStaysOnTheTab() {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "LEGACYPLAN"]
        app.launch()
        sleep(4)
        app.buttons["Plan"].firstMatch.tap()
        sleep(2)
        let log = app.buttons["Log itching"].firstMatch
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        log.tap()
        usleep(400_000)
        Capture.screen("log-tap-after-\(ScreenTourTests.variant)")
        sleep(1)
        XCTAssertTrue(app.staticTexts["Coming up"].exists || app.staticTexts["Plan"].exists, "Still on Plan after logging")
        Capture.screen("log-tap-settled-\(ScreenTourTests.variant)")
    }
}

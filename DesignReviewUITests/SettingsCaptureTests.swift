import XCTest

/// Settings: the list, editing a child, Your data, How Cali Care works.
/// Same DESIGN_VARIANT and DESIGN_OUT as the screen tour; run on an erased simulator.
@MainActor
final class SettingsCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSettings() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "YES"]
        app.launch()
        sleep(3)

        tap(app.buttons["Settings"])
        Capture.screen("settings-1-\(variant)")
        app.swipeUp()
        sleep(1)
        Capture.screen("settings-2-\(variant)")
        app.swipeDown()
        sleep(1)

        tap(app.buttons["Cal"].firstMatch)
        Capture.screen("settings-child-\(variant)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)

        app.swipeUp()
        tap(app.buttons["Export and what's stored where"])
        sleep(1)
        Capture.screen("settings-data-\(variant)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)

        app.swipeUp()
        tap(app.buttons["How Cali Care works"])
        Capture.screen("settings-about-\(variant)")
    }

    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        element.tap()
        sleep(1)
    }
}

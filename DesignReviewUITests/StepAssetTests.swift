import XCTest

/// Captures the VisualSteps screenshots and tap spots on the current iOS.
@MainActor
final class StepAssetTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testWidgetHomeSteps() {
        XCUIApplication().launch()  // installs the app, so its widgets are listed
        Springboard().addHomeWidget(captureAs: "widgetHome_ios27")
    }

    func testWidgetLockSteps() {
        XCUIApplication().launch()
        Springboard().addLockWidgets(captureAs: "widgetLock_ios27")
    }
}

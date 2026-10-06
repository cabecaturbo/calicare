import XCTest

/// The Plan tab before any plan: "Bring in your care plan." and the three ways in.
@MainActor
final class PlanTabCaptureTests: XCTestCase {
    func testEmpty() {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments
        app.launch()
        sleep(3)
        app.buttons["Plan"].firstMatch.tap()
        sleep(2)
        Capture.screen("plan-empty-\(ScreenTourTests.variant)")
    }
}

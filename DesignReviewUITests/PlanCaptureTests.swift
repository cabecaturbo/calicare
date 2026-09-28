import XCTest

/// Plan with routine steps: empty, the editor, steps set up, one ticked.
/// Same DESIGN_VARIANT and DESIGN_OUT as the screen tour; run on an erased simulator.
@MainActor
final class PlanCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testRoutineSteps() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "YES"]
        app.launch()

        tap(app.buttons["Plan"])
        Capture.screen("plan-empty-\(variant)")

        tap(app.buttons["Add steps"])
        add("Wash face", in: app.textFields["Add a morning step"])
        add("Bath", in: app.textFields["Add an evening step"])
        add("Moisturizer", in: app.textFields["Add an evening step"])
        add("Pajamas", in: app.textFields["Add an evening step"])
        Capture.screen("plan-editor-\(variant)")
        app.descendants(matching: .any)["Pajamas"].firstMatch.swipeLeft()
        sleep(1)
        Capture.screen("plan-editor-swipe-\(variant)")
        tap(app.buttons["Pause"])
        tap(app.buttons["Done"])
        sleep(1)
        Capture.screen("plan-steps-\(variant)")

        tap(app.buttons["Bath"])
        sleep(5)
        Capture.screen("plan-ticked-\(variant)")
    }

    private func add(_ name: String, in field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing \(field)")
        field.tap()
        field.typeText(name + "\n")
        sleep(1)
    }

    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        element.tap()
        sleep(1)
    }
}

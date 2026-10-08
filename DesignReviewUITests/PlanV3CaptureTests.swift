import XCTest

/// Plan v3: the list, an active supplement, a not-started one, and a plan
/// note, from the LEGACYPLAN seed. Also checks the provider's words show in full.
@MainActor
final class PlanV3CaptureTests: XCTestCase {
    private var variant: String { ScreenTourTests.variant }
    /// LEGACYPLAN's "Support the skin" line, as the plan wrote it.
    private let noteWords = "Aim to support the skin 3-4x per day, when possible."

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "LEGACYPLAN", "-todoClock", "10:00"]
        app.launch()
        sleep(5)
        app.buttons["Plan"].firstMatch.tap()
        sleep(2)
        return app
    }

    func testPlan() {
        let app = launch()
        Capture.screen("plan-\(variant)-1")
        app.swipeUp()
        sleep(1)
        Capture.screen("plan-\(variant)-2")
        app.swipeUp()
        sleep(1)
        Capture.screen("plan-\(variant)-3")
    }

    func testActiveItem() {
        let app = launch()
        open(app, "Herbal Drops by Brand F")
        Capture.screen("item-active-\(variant)")
    }

    func testNotStartedItem() {
        let app = launch()
        open(app, "Brand J Chewables")
        Capture.screen("item-not-started-\(variant)")
    }

    func testNote() {
        let app = launch()
        if !open(app, "Support the skin", required: false) {
            // Plan v2 kept notes behind "The rest of the plan".
            open(app, "The rest of the plan")
            open(app, "Support the skin")
        }
        Capture.screen("item-note-\(variant)")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", noteWords)).firstMatch.exists,
                      "The provider's words should show in full")
    }

    @discardableResult
    private func open(_ app: XCUIApplication, _ text: String, required: Bool = true) -> Bool {
        let match = NSPredicate(format: "label CONTAINS %@", text)
        for _ in 0..<8 {
            let button = app.buttons.matching(match).firstMatch
            if button.exists && button.isHittable {
                button.tap()
                sleep(2)
                return true
            }
            app.swipeUp()
            sleep(1)
        }
        if required { XCTFail("No row containing \(text)") }
        return false
    }
}

import XCTest

/// Plan v4: a plan with a set length (LEGACYPLAN), one with no length
/// (PLANSTARTED), no plan yet, and an item page. Each state needs a fresh
/// simulator (seeds run only when there's no child yet).
@MainActor
final class PlanV4CaptureTests: XCTestCase {
    private var variant: String { ScreenTourTests.variant }

    private func launch(seed: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + (seed.map { ["-designReviewSeed", $0] } ?? [])
        app.launch()
        sleep(5)
        app.buttons["Plan"].firstMatch.tap()
        sleep(3)
        return app
    }

    func testWithLength() {
        let app = launch(seed: "LEGACYPLAN")
        Capture.screen("plan-length-\(variant)-1")
        app.swipeUp()
        sleep(1)
        Capture.screen("plan-length-\(variant)-2")
        app.swipeUp()
        sleep(1)
        Capture.screen("plan-length-\(variant)-3")
        // An item page: the supplement with dose steps.
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Herbal Drops")).firstMatch
        for _ in 0..<3 where !(tile.exists && tile.isHittable) {
            app.swipeDown()
            sleep(1)
        }
        if tile.exists {
            tile.tap()
            sleep(2)
            Capture.screen("item-\(variant)-1")
            app.swipeUp()
            sleep(1)
            Capture.screen("item-\(variant)-2")
        }
    }

    func testNoLength() {
        _ = launch(seed: "PLANSTARTED")
        Capture.screen("plan-no-length-\(variant)")
    }

    func testNoPlan() {
        _ = launch(seed: "EMPTY")
        Capture.screen("plan-none-\(variant)")
    }
}

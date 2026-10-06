import XCTest

/// The Plan tab with a seeded draft, the review screen, and the started plan.
@MainActor
final class PlanReviewCaptureTests: XCTestCase {
    func testReview() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "PLAN"]
        app.launch()
        sleep(3)
        app.buttons["Plan"].firstMatch.tap()
        sleep(1)
        Capture.screen("careplan-section-\(variant)")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Finish checking")).firstMatch.tap()
        sleep(2)
        Capture.screen("careplan-review-\(variant)")
        app.buttons["Check all"].firstMatch.tap()
        sleep(1)
        app.swipeUp()
        sleep(1)
        Capture.screen("careplan-review-scrolled-\(variant)")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Start plan")).firstMatch.tap()
        sleep(2)
        app.swipeDown()
        sleep(1)
        Capture.screen("careplan-started-plan-\(variant)")
        app.swipeUp()
        sleep(1)
        Capture.screen("careplan-started-plan-scrolled-\(variant)")
    }
}

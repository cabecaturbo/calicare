import XCTest

/// Plan's care plan section and the review screen, from a seeded draft.
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
        app.swipeUp()
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
        let oat = app.buttons["Log Oat bath"].firstMatch
        if oat.waitForExistence(timeout: 3) { oat.tap() }
        sleep(1)
        Capture.screen("careplan-started-plan-scrolled-\(variant)")

        let herb = app.buttons["Start Antimicrobial herb, Brand C"].firstMatch
        if herb.waitForExistence(timeout: 3) {
            herb.tap()
            sleep(2)
            Capture.screen("careplan-supplements-\(variant)")
        }

        let start = app.buttons["Start a patch test"].firstMatch
        if start.waitForExistence(timeout: 3) {
            start.tap()
            sleep(1)
            app.textFields.firstMatch.tap()
            app.textFields.firstMatch.typeText("Calendula balm")
            Capture.screen("careplan-patch-start-\(variant)")
            app.buttons["Start"].firstMatch.tap()
            sleep(2)
            let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
            if allow.waitForExistence(timeout: 3) { allow.tap() }
            sleep(2)
            app.swipeUp()
            sleep(1)
            Capture.screen("careplan-patch-running-\(variant)")
        }
    }
}

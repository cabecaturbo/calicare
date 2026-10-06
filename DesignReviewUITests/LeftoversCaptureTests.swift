import XCTest

/// Food list › Leftovers: add a cooked batch and see it with its days.
@MainActor
final class LeftoversCaptureTests: XCTestCase {
    func testLeftovers() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "PLANSTARTED"]
        app.launch()
        sleep(4)
        app.buttons["Plan"].firstMatch.tap()
        sleep(1)
        let list = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Food")).firstMatch
        for _ in 0..<8 where !list.isHittable { app.swipeUp() }
        list.tap()
        sleep(2)
        let add = app.buttons["Add a cooked batch"].firstMatch
        for _ in 0..<3 where !add.isHittable { app.swipeUp() }
        add.tap()
        sleep(1)
        let name = app.textFields["What did you cook?"].firstMatch
        name.tap()
        name.typeText("Chicken rice")
        Capture.screen("leftovers-add-\(variant)")
        app.buttons["Save"].firstMatch.tap()
        sleep(3)
        if app.buttons["Allow"].exists { app.buttons["Allow"].tap() }
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        sleep(1)
        Capture.screen("leftovers-\(variant)")
    }
}

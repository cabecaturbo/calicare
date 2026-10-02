import XCTest

/// Plan › Food list, from a started plan that names foods to avoid.
@MainActor
final class FoodCaptureTests: XCTestCase {
    func testFoodList() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "PLANSTARTED"]
        app.launch()
        sleep(4)
        app.buttons["Plan"].firstMatch.tap()
        sleep(1)
        let list = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Food list")).firstMatch
        for _ in 0..<8 where !list.isHittable { app.swipeUp() }
        list.tap()
        sleep(2)
        Capture.screen("food-list-empty-\(variant)")
        app.buttons["Add them as paused"].firstMatch.tap()
        sleep(1)
        let field = app.textFields["Add a food"].firstMatch
        for name in ["Oats", "Blueberries", "Sweet potato"] {
            field.tap()
            field.typeText(name + "\n")
            sleep(1)
        }
        Capture.screen("food-list-\(variant)")
    }
}

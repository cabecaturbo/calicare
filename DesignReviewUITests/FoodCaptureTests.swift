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

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Eggs")).firstMatch.tap()
        sleep(1)
        app.buttons["Start a trial"].firstMatch.tap()
        sleep(1)
        let amounts = app.textFields["Amounts, one per day (optional)"].firstMatch
        _ = amounts.waitForExistence(timeout: 3)
        amounts.tap()
        amounts.typeText("1 tsp\n1 tbsp\n1/4 cup")
        Capture.screen("food-trial-start-\(variant)")
        app.buttons["Start"].firstMatch.tap()
        sleep(2)
        app.swipeDown()
        sleep(1)
        let trial = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Eggs")).firstMatch
        trial.tap()
        sleep(1)
        let gave = app.buttons["Gave it today"].firstMatch
        if gave.waitForExistence(timeout: 3) { gave.tap() }
        sleep(2)
        Capture.screen("food-trial-\(variant)")
    }
}

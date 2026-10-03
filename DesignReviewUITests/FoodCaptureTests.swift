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
        for name in ["Oats", "Blueberries", "Sweet potato", "Rice", "Apple", "Kale", "Chicken", "Carrot"] {
            field.tap()
            field.typeText(name + "\n")
            sleep(1)
        }
        Capture.screen("food-list-\(variant)")
        // Meals, plants, and rotation are hidden in version 1 (Features.foodExtras).
        if app.buttons["Log a meal"].firstMatch.exists {
            app.buttons["Log a meal"].firstMatch.tap()
            sleep(1)
            for name in ["Oats", "Blueberries", "Chicken"] { app.buttons[name].firstMatch.tap() }
            Capture.screen("food-meal-\(variant)")
            app.buttons["Log"].firstMatch.tap()
            sleep(2)
            app.swipeDown()
            sleep(1)
            Capture.screen("food-list-plants-\(variant)")
        }
        let rotation = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Rotation")).firstMatch
        if rotation.waitForExistence(timeout: 3) {
            rotation.tap()
            sleep(1)
            Capture.screen("food-rotation-\(variant)")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        let eggs = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Eggs")).firstMatch
        for _ in 0..<6 where !eggs.isHittable { app.swipeUp() }
        eggs.tap()
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

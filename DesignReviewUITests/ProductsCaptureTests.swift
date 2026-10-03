import XCTest

/// Plan › Products: add a few, mark one "never again" with a reason.
@MainActor
final class ProductsCaptureTests: XCTestCase {
    func testProductDiary() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "YES"]
        app.launch()
        sleep(4)
        app.buttons["Plan"].firstMatch.tap()
        sleep(1)
        let diary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Product diary")).firstMatch
        for _ in 0..<8 where !diary.isHittable { app.swipeUp() }
        diary.tap()
        sleep(2)
        Capture.screen("products-empty-\(variant)")
        let field = app.textFields["Add a product"].firstMatch
        for name in ["Oat cream", "Lavender wash", "Free & clear detergent"] {
            field.tap()
            field.typeText(name + "\n")
            sleep(1)
        }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Lavender wash")).firstMatch.tap()
        sleep(1)
        app.buttons["Never again"].firstMatch.tap()
        let reason = app.textFields["What happened? (optional)"].firstMatch
        _ = reason.waitForExistence(timeout: 3)
        reason.tap()
        reason.typeText("Red cheeks after bath")
        Capture.screen("products-never-again-\(variant)")
        app.alerts.buttons["Save"].tap()
        sleep(2)
        Capture.screen("products-\(variant)")
    }
}

import XCTest

/// Progress › Photos: add a spot and open its timeline.
@MainActor
final class PhotosCaptureTests: XCTestCase {
    func testPhotos() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "YES"]
        app.launch()
        sleep(3)
        app.buttons["Progress"].firstMatch.tap()
        sleep(2)
        let add = app.buttons["Add a spot"].firstMatch
        for _ in 0..<5 where !add.isHittable { app.swipeUp() }
        add.tap()
        sleep(1)
        app.textFields.firstMatch.typeText("Left elbow")
        app.buttons["Add"].firstMatch.tap()
        sleep(1)
        Capture.screen("photos-section-\(variant)")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Left elbow")).firstMatch.tap()
        sleep(1)
        Capture.screen("photos-spot-\(variant)")
    }
}

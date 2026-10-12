import XCTest

/// Plan › Caregiver card: the editor, filled in, and the card preview.
@MainActor
final class CaregiverCaptureTests: XCTestCase {
    func testCaregiverCard() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "LEGACYPLAN", "-todoClock", "10:00"]
        app.launch()
        sleep(6)
        app.buttons["Plan"].firstMatch.tap()
        sleep(2)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Caregiver card")).firstMatch
        for _ in 0..<8 where !row.isHittable { app.swipeUp() }
        row.tap()
        sleep(2)
        Capture.screen("caregiver-editor-\(variant)")

        type("Grandma", into: app.textFields["Grandma, the sitter…"].firstMatch)
        type("Cool cloth on the spot, then text us", into: app.textFields["What you’d like them to do"].firstMatch)
        type("Wool blankets", into: app.textFields["One per line"].firstMatch)
        app.buttons["Add a contact"].tap()
        type("Mom", into: app.textFields["Name"].firstMatch)
        type("555 0100", into: app.textFields["Phone"].firstMatch)
        app.swipeUp()
        app.swipeUp()
        sleep(2)
        Capture.screen("caregiver-card-\(variant)")
    }

    private func type(_ text: String, into field: XCUIElement) {
        guard field.waitForExistence(timeout: 5) else { return XCTFail("Missing \(field)") }
        field.tap()
        field.typeText(text)
        sleep(1)
    }
}

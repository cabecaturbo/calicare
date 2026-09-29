import XCTest

/// Progress › Caregiver card: the editor, filled in, and the card preview.
@MainActor
final class CaregiverCaptureTests: XCTestCase {
    func testCaregiverCard() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "SAMPLE"]
        app.launch()
        sleep(8)
        app.terminate()
        app.launch()
        sleep(3)
        app.buttons["Progress"].firstMatch.tap()
        sleep(2)
        app.swipeUp()
        app.buttons["Caregiver card"].firstMatch.tap()
        sleep(2)
        Capture.screen("caregiver-editor-\(variant)")

        type("Apple slices\nRice cakes", into: app.textFields["One per line"].firstMatch)
        type("Cool cloth on the spot, then text us", into: app.textFields["What you'd like them to do"].firstMatch)
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

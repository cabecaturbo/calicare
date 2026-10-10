import XCTest

/// Onboarding and every setup guide screen, from a fresh install.
/// Same DESIGN_VARIANT and DESIGN_OUT as the screen tour; run on an erased simulator.
@MainActor
final class OnboardingCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private var variant: String { ScreenTourTests.variant }

    func testOnboardingAndGuides() {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments
        app.launch()

        sleep(2)
        Capture.screen("onb-1-welcome-\(variant)")
        tap(app.buttons["Add your child"])

        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Cal")
        Capture.screen("onb-2-child-\(variant)")
        // A fresh simulator can show a keyboard tip with its own "Continue".
        let plan = app.staticTexts["Bring in your care plan"]
        for _ in 0..<5 where !plan.exists {
            app.buttons["Continue"].firstMatch.tap()
            sleep(1)
        }
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        Capture.screen("onb-3-plan-\(variant)")
        tap(app.buttons["Skip for now"])

        let reminders = app.staticTexts["Gentle reminders"]
        XCTAssertTrue(reminders.waitForExistence(timeout: 5))

        Capture.screen("onb-4-reminders-\(variant)")
        tap(app.buttons["Skip for now"])

        Capture.screen("onb-5-anywhere-lock-\(variant)")
        tap(app.buttons["Home"])
        Capture.screen("onb-5-anywhere-home-\(variant)")
        tap(app.buttons["Control Center"])
        Capture.screen("onb-5-anywhere-cc-\(variant)")

        for (segment, key, count) in [("Lock Screen", "lock", 6), ("Home", "home", 6), ("Control Center", "cc", 5)] {
            tap(app.buttons[segment])
            tap(app.buttons[segment == "Lock Screen" ? "Add it to my Lock Screen" : "Show me how"])
            for step in 1...count {
                Capture.screen("guide-\(key)-\(step)-\(variant)")
                tap(app.buttons["Next"])
            }
            Capture.screen("guide-\(key)-done-\(variant)")
            tap(app.buttons["Done"])
        }

        tap(app.buttons["Go to Today"])
        sleep(2)
        Capture.screen("onb-6-today-\(variant)")
    }

    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        element.tap()
        sleep(1)
    }
}

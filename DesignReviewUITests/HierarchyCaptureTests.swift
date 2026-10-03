import XCTest

/// Before and after shots for the hierarchy pass: every screen, top to
/// bottom, from the LEGACYPLAN seed (a plan shaped like a real import).
@MainActor
final class HierarchyCaptureTests: XCTestCase {
    func testHierarchyScreens() {
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "LEGACYPLAN"]
        app.launch()
        sleep(5)

        scroll(app, "today-\(variant)")
        tab(app, "Plan")
        scroll(app, "plan-\(variant)")

        // Patch tests: the start sheet.
        tab(app, "Plan")
        if reveal(app, app.buttons["Start a patch test"].firstMatch) {
            app.buttons["Start a patch test"].firstMatch.tap()
            sleep(1)
            Capture.screen("patch-test-start-\(variant)")
            if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap() }
            sleep(1)
        }

        // Add a visit.
        tab(app, "Plan")
        if reveal(app, app.buttons["Add a visit"].firstMatch) {
            app.buttons["Add a visit"].firstMatch.tap()
            sleep(1)
            Capture.screen("add-visit-\(variant)")
            if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap() }
            sleep(1)
        }

        // Edit routine.
        tab(app, "Plan")
        if reveal(app, app.buttons["Edit routine"].firstMatch) {
            app.buttons["Edit routine"].firstMatch.tap()
            sleep(1)
            scroll(app, "edit-routine-\(variant)")
            if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
            sleep(1)
        }

        // Food list.
        tab(app, "Plan")
        let food = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Food list")).firstMatch
        if reveal(app, food) {
            food.tap()
            sleep(2)
            scroll(app, "food-list-\(variant)")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        tab(app, "Progress")
        scroll(app, "progress-\(variant)")
        app.swipeDown()
        app.swipeDown()
        if app.buttons["Settings"].firstMatch.waitForExistence(timeout: 3) {
            app.buttons["Settings"].firstMatch.tap()
            sleep(1)
            scroll(app, "settings-\(variant)")
        }
    }

    /// Back to the top, then a tab. The glass bar hides while scrolling.
    private func tab(_ app: XCUIApplication, _ name: String) {
        for _ in 0..<4 { app.swipeDown() }
        guard app.buttons[name].firstMatch.waitForExistence(timeout: 3) else { return }
        app.buttons[name].firstMatch.tap()
        sleep(1)
        for _ in 0..<4 { app.swipeDown() }
    }

    /// Scrolls until `element` can be tapped. Returns whether it got there.
    private func reveal(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
        for _ in 0..<30 where !element.isHittable { app.swipeUp() }
        return element.isHittable
    }

    /// A shot per screenful, top to bottom, until the page stops moving.
    private func scroll(_ app: XCUIApplication, _ name: String) {
        var last = Data()
        for page in 1...12 {
            let png = Capture.screen("\(name)-\(page)").pngRepresentation
            if png == last { break }
            last = png
            app.swipeUp()
            sleep(1)
        }
    }
}

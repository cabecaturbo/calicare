import XCTest

/// The Today pieces: first run, rating last night, "Add where", Mood, and
/// swipe to delete. Same DESIGN_VARIANT and DESIGN_OUT as the screen tour;
/// run on a freshly erased simulator (the seed only adds Cal once).
@MainActor
final class TodayCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private var variant: String { ScreenTourTests.variant }

    func testFirstRun() {
        launch(seed: "EMPTY")
        sleep(2)
        Capture.screen("today-first-run-\(variant)")
    }

    func testTodayPieces() {
        let app = launch(seed: "UNRATED")
        sleep(2)
        Capture.screen("today-\(variant)")
        guard variant != "night" else { return }

        // Rating last night is only offered before 7 PM.
        if app.buttons["Last night was okay"].exists {
            tap(app.buttons["Last night was okay"])
            sleep(7)
            Capture.screen("today-rated-\(variant)")
        }

        tap(app.buttons["More"])
        tap(app.buttons["Flare"])
        tap(app.buttons["Add where"])
        let outline = app.otherElements["Body outline, front"]
        XCTAssertTrue(outline.waitForExistence(timeout: 5))
        outline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        outline.coordinate(withNormalizedOffset: CGVector(dx: 0.14, dy: 0.57)).tap()
        sleep(1)
        Capture.screen("today-add-where-\(variant)")
        tap(app.buttons["Save"])
        sleep(7)

        // The first tap after a sheet closes can land before the bar is ready.
        for _ in 0..<3 where !app.buttons["Mood"].exists {
            app.buttons["More"].tap()
            sleep(1)
        }
        tap(app.buttons["Mood"])
        sleep(1)
        Capture.screen("today-mood-\(variant)")
        tap(app.buttons["Mood: Great"])
        sleep(7)

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Flare'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        usleep(500_000)
        Capture.screen("today-swipe-\(variant)")
    }

    @discardableResult
    private func launch(seed: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", seed]
        app.launch()
        return app
    }

    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        element.tap()
        sleep(1)
    }
}

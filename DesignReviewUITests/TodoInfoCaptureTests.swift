import XCTest

/// To do at three times of day, an item sheet, and Info with its screens,
/// from the LEGACYPLAN seed (a made-up plan shaped like a real import).
@MainActor
final class TodoInfoCaptureTests: XCTestCase {
    private func launch(clock: String, allDone: Bool = false, ask: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "LEGACYPLAN", "-todoClock", clock,
                                                                 "-todoAllDone", allDone ? "YES" : "NO", "-todoAsk", ask ? "YES" : "NO"]
        app.launch()
        sleep(5)
        return app
    }

    private var variant: String { ScreenTourTests.variant }

    func testMorning() {
        let app = launch(clock: "08:05")
        tab(app, "To do")
        scroll(app, "todo-morning-\(variant)")
        // The skin care sheet: steps in plain words, then the provider's words.
        for _ in 0..<4 { app.swipeDown() }
        let skin = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Do skin care")).element(boundBy: 1)
        if skin.waitForExistence(timeout: 3) {
            skin.tap()
            sleep(1)
            scroll(app, "todo-skin-sheet-\(variant)")
        }
    }

    func testBedtime() {
        let app = launch(clock: "19:40")
        tab(app, "To do")
        scroll(app, "todo-bedtime-\(variant)")
    }

    func testAllDone() {
        let app = launch(clock: "21:30", allDone: true)
        tab(app, "To do")
        scroll(app, "todo-alldone-\(variant)")
    }

    func testAsk() {
        let app = launch(clock: "08:05", ask: true)
        tab(app, "To do")
        sleep(2)
        Capture.screen("todo-ask-\(variant)")
    }

    func testInfo() {
        let app = launch(clock: "10:00")
        tab(app, "Info")
        Capture.screen("info-\(variant)")
        for (row, name) in [("Supplements", "info-supplements"), ("Patch tests", "info-patch-tests"), ("Care plan", "info-care-plan")] {
            let link = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", row)).firstMatch
            guard link.waitForExistence(timeout: 3) else { continue }
            link.tap()
            sleep(2)
            scroll(app, "\(name)-\(variant)")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        for _ in 0..<3 { app.swipeDown() }
        if app.buttons[name].firstMatch.waitForExistence(timeout: 3) { app.buttons[name].firstMatch.tap() }
        sleep(1)
    }

    private func scroll(_ app: XCUIApplication, _ name: String) {
        var last = Data()
        for page in 1...10 {
            let png = Capture.screen("\(name)-\(page)").pngRepresentation
            if png == last { break }
            last = png
            app.swipeUp()
            sleep(1)
        }
    }
}

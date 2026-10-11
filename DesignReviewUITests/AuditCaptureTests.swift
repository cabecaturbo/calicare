import XCTest

/// Screens the other capture tests don't reach, for the visual audit:
/// Undo, To do in the afternoon and an item, Progress since visit and empty,
/// Coming up, the full plan, the guides from Settings, plan import offline,
/// and Settings with notifications off. Same DESIGN_VARIANT / DESIGN_OUT;
/// run each test on a freshly erased simulator (seeds only apply once).
@MainActor
final class AuditCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private var variant: String { ScreenTourTests.variant }

    private func launch(_ seed: String, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", seed] + extra
        app.launch()
        sleep(5)
        return app
    }

    private func tap(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 5) else { return XCTFail("Missing \(element)") }
        element.tap()
        sleep(1)
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        tap(app.tabBars.buttons[name].exists ? app.tabBars.buttons[name] : app.buttons[name].firstMatch)
        sleep(1)
    }

    /// Today: log, the banner with Undo, then after Undo.
    func testLogAndUndo() {
        let app = launch("EMPTY")
        Capture.screen("today-first-run-\(variant)")
        tap(app.buttons["Log itching"].firstMatch)
        sleep(1)
        Capture.screen("log-banner-\(variant)")
        let undo = app.descendants(matching: .any).matching(identifier: "Undo").firstMatch
        if undo.waitForExistence(timeout: 3) { undo.tap() }
        sleep(2)
        Capture.screen("log-undone-\(variant)")
        tap(app.buttons["More to log"].firstMatch)
        sleep(1)
        Capture.screen("log-more-\(variant)")
    }

    /// To do mid-day, then one item's sheet.
    func testTodoAfternoon() {
        let app = launch("LEGACYPLAN", ["-todoClock", "13:00"])
        tab(app, "To do")
        Capture.screen("todo-afternoon-\(variant)")
        let rows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Give"))
        let item = rows.count > 1 ? rows.element(boundBy: 1) : rows.firstMatch
        if item.waitForExistence(timeout: 3) {
            item.tap()
            sleep(2)
            Capture.screen("todo-item-\(variant)")
        }
    }

    /// Progress since the last visit, Coming up, and the full plan.
    func testSinceVisitAndPlanPages() {
        let app = launch("LEGACYPLAN", ["-todoClock", "10:00"])
        tab(app, "Progress")
        let since = app.buttons["Since visit"]
        if since.waitForExistence(timeout: 3) {
            since.tap()
            sleep(2)
            Capture.screen("progress-since-visit-\(variant)")
        }
        tab(app, "Plan")
        let seeAll = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "See all")).firstMatch
        if seeAll.waitForExistence(timeout: 3) {
            seeAll.tap()
            sleep(2)
            Capture.screen("plan-coming-up-\(variant)")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
        let full = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Full plan")).firstMatch
        if full.waitForExistence(timeout: 3) {
            full.tap()
            sleep(2)
            Capture.screen("plan-full-\(variant)")
        }
    }

    /// Progress with nothing logged.
    func testProgressEmpty() {
        let app = launch("EMPTY")
        tab(app, "Progress")
        Capture.screen("progress-empty-\(variant)")
    }

    /// Plan import that can't reach the internet.
    func testPlanImportOffline() {
        let app = launch("EMPTY", ["-designReviewOffline", "YES"])
        tab(app, "Plan")
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add a PDF")).firstMatch)
        sleep(2)
        Capture.screen("plan-import-offline-\(variant)")
    }

    /// Settings: notifications off, and the two guides from Widgets and Siri.
    func testSettingsPieces() {
        let app = launch("YES", ["-designReviewNotifications", "deny"])
        tap(app.buttons["Settings"].firstMatch)
        sleep(1)
        Capture.screen("settings-top-\(variant)")
        app.swipeUp()
        sleep(1)
        Capture.screen("settings-reminders-off-\(variant)")
        for (row, name) in [("Lock Screen widget", "settings-guide-lock"), ("Control Center", "settings-guide-cc"), ("Siri", "settings-siri")] {
            let link = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", row)).firstMatch
            for _ in 0..<3 where !link.isHittable { app.swipeUp() }
            guard link.waitForExistence(timeout: 3) else { continue }
            link.tap()
            sleep(2)
            Capture.screen("\(name)-\(variant)")
            let close = app.buttons["Close"].firstMatch
            if close.exists { close.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
            sleep(1)
        }
    }
}

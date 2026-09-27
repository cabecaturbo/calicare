import XCTest

/// Captures the real Control Center "add a control" flow on the current iOS,
/// so the setup guide's wording matches what a parent will see.
@MainActor
final class ControlCenterStepTests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = true
    }

    func testControlCenterSteps() {
        XCUIApplication().launch()  // installs the app, so its control is listed
        Springboard().goHome()

        // 1. Open Control Center: swipe down from the top-right corner.
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.005))
        top.press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)))
        sleep(2)
        Capture.screen("controlCenter_ios27_step1")
        log("step1")

        // 2. Touch and hold an empty area to edit.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88)).press(forDuration: 2)
        sleep(2)
        Capture.screen("controlCenter_ios27_step2")
        log("step2")

        // 3. Add a Control.
        let add = springboard.buttons["Add a Control"].firstMatch
        if add.waitForExistence(timeout: 4) {
            Capture.tapSpot("controlCenter_ios27_step2", add)
            add.tap()
            sleep(3)
        }
        Capture.screen("controlCenter_ios27_step3")
        log("step3")

        // 4. Search for CaliCare.
        let search = springboard.searchFields.firstMatch
        if search.waitForExistence(timeout: 4) {
            search.tap()
            search.typeText("CaliCare")
            sleep(2)
        }
        Capture.screen("controlCenter_ios27_step4")
        log("step4")

        // 5. Our control, if it's listed.
        let ours = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'itch'")).firstMatch
        if ours.waitForExistence(timeout: 4) {
            Capture.tapSpot("controlCenter_ios27_step4", ours)
            ours.tap()
            sleep(3)
        }
        Capture.screen("controlCenter_ios27_step5")
        log("step5")
    }

    /// Writes the visible button and cell labels next to the screenshots.
    private func log(_ name: String) {
        guard let folder = Capture.folder else { return }
        let labels = springboard.buttons.allElementsBoundByIndex.map { "button: \($0.label)" }
            + springboard.cells.allElementsBoundByIndex.map { "cell: \($0.label)" }
            + springboard.staticTexts.allElementsBoundByIndex.prefix(40).map { "text: \($0.label)" }
        try? labels.joined(separator: "\n").write(
            to: folder.appendingPathComponent("\(name)-labels.txt"), atomically: true, encoding: .utf8)
    }
}

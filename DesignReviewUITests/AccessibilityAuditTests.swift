import XCTest

/// Apple's accessibility audit (labels, contrast, clipped text, Dynamic Type,
/// hit areas) on each main screen. Issues are written to DESIGN_OUT as
/// a11y-<variant>.txt instead of failing, so one run lists everything.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    private var lines: [String] = []

    func testMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", "LEGACYPLAN", "-todoClock", "10:00"]
        app.launch()
        sleep(6)
        audit(app, "Today")
        for tab in ["To do", "Progress", "Plan"] {
            app.buttons[tab].firstMatch.tap()
            sleep(2)
            audit(app, tab)
        }
        app.buttons["Settings"].firstMatch.tap()
        sleep(2)
        audit(app, "Settings")
        write()
    }

    func testOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments
        app.launch()
        sleep(2)
        audit(app, "Welcome")
        app.buttons["Add your child"].tap()
        sleep(1)
        app.textFields["Name"].typeText("Cal")
        audit(app, "Your child")
        write()
    }

    private func audit(_ app: XCUIApplication, _ screen: String) {
        do {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { "\($0.elementType.rawValue) “\($0.label)”" } ?? "screen"
                self.lines.append("\(screen) · \(issue.auditType) · \(element) · \(issue.compactDescription)")
                return true
            }
        } catch {
            lines.append("\(screen) · audit failed: \(error)")
        }
    }

    private func write() {
        guard let folder = ProcessInfo.processInfo.environment["DESIGN_OUT"] else { return }
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: folder).appendingPathComponent("a11y-\(ScreenTourTests.variant)-\(name.split(separator: " ").last ?? "").txt")
        try? (lines.isEmpty ? "No issues.\n" : lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

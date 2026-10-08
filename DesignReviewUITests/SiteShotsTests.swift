import XCTest

/// The website's app screenshots (web/shots), from the current app. One per
/// run on a fresh simulator: SITE_SHOT is today, todo, progress, or plan;
/// DESIGN_VARIANT picks day or night.
@MainActor
final class SiteShotsTests: XCTestCase {
    func testShot() {
        let kind = ProcessInfo.processInfo.environment["SITE_SHOT"] ?? "today"
        let (seed, tab): (String, String?) = switch kind {
        case "todo": ("LEGACYPLAN", "To do")
        case "plan": ("LEGACYPLAN", "Plan")
        case "progress": ("SAMPLE", "Progress")
        default: ("SAMPLE", nil)
        }
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments + ["-designReviewSeed", seed, "-todoClock", "08:05"]
        app.launch()
        sleep(5)
        if let tab { app.buttons[tab].firstMatch.tap() }
        sleep(4)
        Capture.screen("site-\(kind)-\(ScreenTourTests.variant)")
    }
}

import XCTest

/// Drives the three motions for the screen recording in docs/screenshots/motion:
/// logging from Today (Press, then Done), a To do check-off (Done), and
/// opening Progress (the week's bars arrive). Run on a fresh simulator.
@MainActor
final class MotionRecordingTests: XCTestCase {
    func testLogCheckOffAndProgress() {
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments
            + ["-designReviewSeed", "LEGACYPLAN", "-todoClock", "08:05"]
            + (ProcessInfo.processInfo.environment["MOTION_REDUCE"] == "1" ? ["-UIReduceMotionPreference", "YES"] : [])
        app.launch()
        sleep(4)

        let log = app.buttons["Log itching"].firstMatch
        if log.waitForExistence(timeout: 5) { log.tap() }
        sleep(3)

        app.buttons["To do"].firstMatch.tap()
        sleep(2)
        let step = app.buttons.matching(NSPredicate(format: "label == %@", "Wash face")).firstMatch
        if step.waitForExistence(timeout: 3) { step.tap() } else { app.buttons.element(boundBy: 6).tap() }
        sleep(2)

        app.buttons["Progress"].firstMatch.tap()
        sleep(3)
    }
}

import XCTest

/// Real iOS 27 screenshots for the setup guides and the widget looks.
/// Run by scripts/capture-guides.sh on the "CaliCare Captures" simulator,
/// after the shell tour has added a child and a few logs.
@MainActor
final class GuideCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Starts from a known family (debug seed): Cal, onboarded, a few logs.
    func testSeed() {
        let app = XCUIApplication()
        app.launchArguments = ["-designReviewSeed", "YES", "-designReviewNight", "NO"]
        app.launch()
        sleep(6)
        XCUIDevice.shared.press(.home)
        sleep(1)
    }

    /// Home Screen path: home, jiggle, the Edit menu, the gallery searched for
    /// Cali Care, the size picker, placed; then home with the widget.
    func testHomeGuide() {
        XCUIApplication().launch()
        let board = Springboard()
        board.addHomeWidget(page: 0, search: "Cali Care", captureAs: "home")
        board.goHome()
        sleep(2)
        Capture.screen("home_done")
        // The medium widget too, for the looks.
        board.addHomeWidget(page: 1)
    }

    /// Lock Screen path, then the Lock Screen with both widgets.
    func testLockGuide() {
        let board = Springboard()
        board.addLockWidgets(pages: [0, 1], captureAs: "lock")
        board.showLockScreen()
        sleep(2)
        Capture.screen("lock_done")
        XCUIDevice.shared.press(.home)
    }

    /// Control Center path: swipe down, edit, Add a Control, search, add, finish.
    func testControlGuide() {
        let board = Springboard()
        let app = board.app
        board.goHome()
        Capture.screen("cc_step1")
        Capture.tapSpot("cc_step1", x: 0.9, y: 0.01)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.005))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.6)))
        sleep(2)
        Capture.screen("cc_step2")
        Capture.tapSpot("cc_step2", x: 0.5, y: 0.88)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88)).press(forDuration: 2)
        sleep(2)
        let add = app.buttons["Add a Control"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        Capture.screen("cc_step3")
        Capture.tapSpot("cc_step3", add)
        add.tap()
        sleep(3)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Cali Care")
        sleep(2)
        let ours = app.buttons["Log Itchy"].firstMatch
        XCTAssertTrue(ours.waitForExistence(timeout: 5))
        Capture.screen("cc_step4")
        Capture.tapSpot("cc_step4", ours)
        ours.tap()
        sleep(3)
        Capture.screen("cc_step5")
        // Tap an empty area to finish, then show Control Center in use.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)).tap()
        sleep(2)
        Capture.screen("cc_done")
        XCUIDevice.shared.press(.home)
        sleep(1)
    }

    /// One Home Screen look (LOOK = default, dark, clear, tinted), captured on the
    /// Home Screen and the Lock Screen. The script sets light or dark appearance
    /// and DESIGN_VARIANT (which pins our widgets' day or night palette).
    func testLook() {
        let look = ProcessInfo.processInfo.environment["LOOK"] ?? "default"
        let variant = ScreenTourTests.variant
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments
        app.launch()
        sleep(2)

        let board = Springboard()
        board.goHome()
        // Widgets fill the page, so enter edit mode from an app's menu.
        let photos = board.app.icons["Photos"].firstMatch
        XCTAssertTrue(photos.waitForExistence(timeout: 5))
        photos.press(forDuration: 1.5)
        let editHome = board.app.buttons["Edit Home Screen"].firstMatch
        XCTAssertTrue(editHome.waitForExistence(timeout: 5))
        editHome.tap()
        sleep(2)
        board.app.buttons["Edit"].tap()
        sleep(1)
        board.app.descendants(matching: .any)["Customize"].firstMatch.tap()
        sleep(3)
        Capture.screen("look_\(look)_\(variant)_customize")
        // The Customize sheet's four looks, left to right (iOS 27). They have no labels.
        // With Clear or Tinted chosen the sheet grows (tint sliders, Light / Dark /
        // Auto), which moves the row of looks up.
        let x: [String: CGFloat] = ["default": 0.163, "dark": 0.388, "clear": 0.612, "tinted": 0.837]
        let names = ["default": "Default", "dark": "Dark", "clear": "Clear", "tinted": "Tinted"]
        let label = board.app.staticTexts[names[look] ?? "Default"].firstMatch
        if label.waitForExistence(timeout: 3) {
            label.tap()
        } else {
            let expanded = board.app.sliders.count > 0
            board.app.coordinate(withNormalizedOffset: CGVector(dx: x[look] ?? 0.163, dy: expanded ? 0.60 : 0.883)).tap()
        }
        sleep(2)
        // Follow the system appearance, which the script sets to light or dark.
        let auto = board.app.buttons["Auto"].firstMatch
        if auto.waitForExistence(timeout: 2) { auto.tap(); sleep(2) }
        Capture.screen("look_\(look)_\(variant)_customized")
        board.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        sleep(1)
        XCUIDevice.shared.press(.home)
        sleep(2)
        Capture.screen("look_\(look)_\(variant)_home")

        if look == "default" || look == "dark" {
            let itchy = board.app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Log itching'")).firstMatch
            if itchy.waitForExistence(timeout: 3) {
                itchy.tap()
                sleep(3)
                Capture.screen("look_\(look)_\(variant)_logged")
                // Undo, so the next looks show the widget, not "Logged".
                let undo = board.app.buttons["Undo"].firstMatch
                if undo.waitForExistence(timeout: 3) { undo.tap(); sleep(3) }
            }
        }
        board.showLockScreen()
        sleep(2)
        Capture.screen("look_\(look)_\(variant)_lock")
        XCUIDevice.shared.press(.home)
    }
}

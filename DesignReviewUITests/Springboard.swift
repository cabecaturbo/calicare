import XCTest

/// Drives the simulator's Home Screen and Lock Screen (iOS 27).
@MainActor
struct Springboard {
    let app = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// Taps away system tips (e.g. the keyboard swipe tip) that cover the screen.
    func dismissTips() {
        let tip = app.buttons["Continue"]
        if tip.exists { tip.tap(); sleep(1) }
    }

    /// The first Home Screen page: stock apps only, with room below them.
    func goHome() {
        XCUIDevice.shared.press(.home)
        sleep(1)
        XCUIDevice.shared.press(.home)
        sleep(2)
        dismissTips()
    }

    /// Touch and hold until the icons jiggle (delete badges appear).
    func enterEditMode(at spot: CGVector) {
        for _ in 0..<3 {
            app.coordinate(withNormalizedOffset: spot).press(forDuration: 2)
            if app.buttons["DeleteButton"].firstMatch.waitForExistence(timeout: 3) { return }
        }
        XCTFail("Home Screen didn't enter edit mode")
    }

    /// Adds a CaliCare widget from the Home Screen. `page` 0 is the small widget,
    /// 1 the medium. With `captureAs`, saves each step and where to tap.
    func addHomeWidget(page: Int = 0, search: String? = nil, captureAs prefix: String? = nil) {
        let spot = CGVector(dx: 0.5, dy: 0.68)
        goHome()
        step(prefix, 1, tapAt: spot)
        enterEditMode(at: spot)
        sleep(1)

        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        step(prefix, 2, element: edit)
        edit.tap()
        sleep(1)
        dismissTips()

        let add = app.buttons["Add Widget"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        step(prefix, 3, element: add)
        add.tap()
        sleep(3)
        dismissTips()

        if let search {
            let field = app.searchFields.firstMatch
            if field.waitForExistence(timeout: 3) {
                field.tap()
                field.typeText(search)
                sleep(2)
            }
        }
        let cell = app.cells["Cali Care"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        step(prefix, 4, element: cell)
        cell.tap()
        sleep(3)

        for _ in 0..<page {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Cali Care,'")).firstMatch.swipeLeft()
            sleep(2)
        }
        let confirm = app.buttons[" Add Widget"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        step(prefix, 5, element: confirm)
        confirm.tap()
        sleep(3)

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        step(prefix, 6, element: done)
        done.tap()
        sleep(2)
    }

    private func step(_ prefix: String?, _ number: Int, element: XCUIElement) {
        guard let prefix else { return }
        let name = "\(prefix)_step\(number)"
        Capture.screen(name)
        Capture.tapSpot(name, element)
    }

    private func step(_ prefix: String?, _ number: Int, tapAt spot: CGVector) {
        guard let prefix else { return }
        let name = "\(prefix)_step\(number)"
        Capture.screen(name)
        Capture.tapSpot(name, x: spot.dx, y: spot.dy)
    }

    /// Wakes the simulator to its Lock Screen.
    func showLockScreen() {
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
    }

    /// Adds CaliCare Lock Screen widgets. `pages` lists which widgets in the
    /// CaliCare row to add: 0 is Itchy (circular), 1 is Last night.
    func addLockWidgets(pages: [Int] = [0], captureAs prefix: String? = nil) {
        let spot = CGVector(dx: 0.5, dy: 0.45)
        showLockScreen()
        step(prefix, 1, tapAt: spot)
        app.coordinate(withNormalizedOffset: spot).press(forDuration: 2)
        sleep(2)

        let customize = app.buttons["posterboard-customize-button"]
        XCTAssertTrue(customize.waitForExistence(timeout: 5))
        step(prefix, 2, element: customize)
        customize.tap()
        sleep(4)

        let area = app.buttons["grouped-widgets-reticle-view"].firstMatch
        XCTAssertTrue(area.waitForExistence(timeout: 5))
        step(prefix, 3, element: area)
        area.tap()
        sleep(3)

        let itchy = app.buttons["Cali Care, Itchy"]
        for (i, page) in pages.enumerated() {
            // After one widget is added the sheet may stay on CaliCare's page.
            let cell = app.cells["Cali Care"]
            if i == 0 || !itchy.exists {
                XCTAssertTrue(cell.waitForExistence(timeout: 5))
                if i == 0 { step(prefix, 4, element: cell) }
                cell.tap()
                sleep(3)
            }
            let widget = app.buttons[page == 0 ? "Cali Care, Itchy" : "Cali Care, Last night"]
            if page == 1, !widget.isHittable, itchy.exists {
                itchy.swipeLeft()
                sleep(2)
            }
            XCTAssertTrue(widget.waitForExistence(timeout: 5))
            if i == 0 { step(prefix, 5, element: widget) }
            widget.tap()
            sleep(3)
        }

        // The gallery stays up after adding; put it away, then save.
        let done = app.buttons["editing-done"]
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99))
        let grabber = app.buttons["Sheet Grabber"].firstMatch
        if grabber.exists {
            grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: bottom)
            sleep(2)
        }
        if !done.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.42)).tap()
            sleep(2)
        }
        XCTAssertTrue(done.waitForExistence(timeout: 5) && done.isHittable)
        step(prefix, 6, element: done)
        done.tap()
        sleep(3)
    }
}

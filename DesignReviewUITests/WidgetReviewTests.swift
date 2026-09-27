import XCTest

/// Home Screen and Lock Screen widgets in each variant. Run `testAddWidgets`
/// once (after the screen tour, so there's a child and some logs), then
/// `testCaptureWidgets` per DESIGN_VARIANT.
@MainActor
final class WidgetReviewTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAddWidgets() {
        let board = Springboard()
        board.addHomeWidget(page: 0)
        board.addHomeWidget(page: 1)
        board.addLockWidgets(pages: [0, 1])
    }

    func testAddLockWidgets() {
        Springboard().addLockWidgets(pages: [0, 1])
    }

    func testCaptureWidgets() {
        // Launching with the variant pins day or night for the widgets too.
        let app = XCUIApplication()
        app.launchArguments = ScreenTourTests.launchArguments
        app.launch()
        sleep(3)

        let board = Springboard()
        board.goHome()
        sleep(3)
        Capture.screen("20-widgets-home")

        let itchy = board.app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Log itching'")).firstMatch
        if itchy.waitForExistence(timeout: 3) {
            itchy.tap()
            sleep(4)
            Capture.screen("21-widgets-home-logged")
        }

        board.showLockScreen()
        sleep(2)
        Capture.screen("22-widgets-lock-screen")
        XCUIDevice.shared.press(.home)
    }
}

import XCTest

/// Saves full-screen simulator screenshots to the folder in DESIGN_OUT
/// (passed as TEST_RUNNER_DESIGN_OUT to xcodebuild).
@MainActor
enum Capture {
    static var folder: URL? {
        ProcessInfo.processInfo.environment["DESIGN_OUT"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    @discardableResult
    static func screen(_ name: String) -> XCUIScreenshot {
        let shot = XCUIScreen.main.screenshot()
        if let folder {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
        }
        return shot
    }

    /// Records where an element sits, as fractions of the screen, for the tap ring.
    static func tapSpot(_ name: String, _ element: XCUIElement) {
        let screen = XCUIApplication(bundleIdentifier: "com.apple.springboard").frame
        let f = element.frame
        tapSpot(name, x: f.midX / screen.width, y: f.midY / screen.height)
    }

    static func tapSpot(_ name: String, x: CGFloat, y: CGFloat) {
        guard let folder else { return }
        let line = String(format: "%@ %.3f %.3f\n", name, x, y)
        let url = folder.appendingPathComponent("tap-spots.txt")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

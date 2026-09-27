import SwiftUI
import UIKit

/// Turns a weekly card into a PNG for sharing (3x: 1800 × 2250 pixels).
public enum WeeklyCardRenderer {
    @MainActor
    public static func image(for report: WeeklyReport, calendar: Calendar = .autoupdatingCurrent) -> UIImage? {
        FontRegistry.registerAll()
        let renderer = ImageRenderer(content: WeeklyCardView(report: report, calendar: calendar))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Writes the card to a temporary file named like "Cal week Sep 20 – 26.png",
    /// so Messages and Mail show a sensible name.
    @MainActor
    public static func file(for report: WeeklyReport, calendar: Calendar = .autoupdatingCurrent) throws -> URL {
        guard let data = image(for: report, calendar: calendar)?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        let name = "\(report.child.name) week \(report.dateRange(calendar: calendar))"
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url, options: .atomic)
        return url
    }
}

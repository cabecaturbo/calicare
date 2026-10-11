import SwiftUI
import UIKit

/// Turns weekly cards into images for sharing, at 3x.
public enum WeeklyCardRenderer {
    /// The full card: 1800 × 2250 pixels.
    @MainActor
    public static func image(for card: WeeklyCard) -> UIImage? {
        render(WeeklyCardView(card: card))
    }

    @MainActor
    public static func image(for report: WeeklyReport, calendar: Calendar = .autoupdatingCurrent) -> UIImage? {
        image(for: WeeklyCard(report: report, calendar: calendar))
    }

    /// The compact Messages bubble: 1800 × 1080 pixels.
    @MainActor
    public static func bubbleImage(for card: WeeklyCard) -> UIImage? {
        render(WeeklyBubbleView(card: card))
    }

    /// Writes the card to a temporary file named like "Cal week Sep 20 – 26.png",
    /// so Messages and Mail show a sensible name.
    @MainActor
    public static func file(for report: WeeklyReport, calendar: Calendar = .autoupdatingCurrent) throws -> URL {
        let card = WeeklyCard(report: report, calendar: calendar)
        guard let data = image(for: card)?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        let name = "\(card.childName) week \(card.dateRange)".replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The "Share this week" picture: 1800 × 1740 pixels.
    @MainActor
    public static func shareImage(_ card: WeekShareCard) -> UIImage? {
        render(WeekShareCardView(card: card))
    }

    /// Writes the share picture to a temporary file named like "Cal's week Sep 21–27.png".
    /// It stays on the phone until the parent sends it.
    @MainActor
    public static func shareFile(_ card: WeekShareCard) throws -> URL {
        guard let data = shareImage(card)?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        let name = "\(card.childName)'s week \(card.rangeLabel)".replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    @MainActor
    private static func render(_ view: some View) -> UIImage? {
        FontRegistry.registerAll()
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

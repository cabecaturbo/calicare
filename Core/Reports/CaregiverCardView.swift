import SwiftUI
import UIKit

/// The caregiver card as a page (DESIGN.md §10): paper, the wordmark, a
/// Newsreader headline, ledger sections, "Not medical advice" at the foot.
/// 600 × 750 points, always the day palette, fixed type sizes.
public struct CaregiverCardView: View {
    public static let size = CGSize(width: 600, height: 750)

    let card: CaregiverCard
    private let palette = Palette.day

    public init(card: CaregiverCard) {
        self.card = card
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Cali Care")
                .font(TypeStyle.title.font)
                .foregroundStyle(palette.ink)
            palette.ink.frame(height: Rule.width)
                .padding(.top, Spacing.x2)

            Text("Looking after \(card.childName)")
                .font(TypeStyle.display.font)
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.top, CardSpacing.block)
            Text("From \(card.childName)’s family. Thank you.")
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
                .padding(.top, Spacing.x1)

            VStack(alignment: .leading, spacing: Spacing.x5) {
                ForEach(card.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: Spacing.x1) {
                        Text(section.title)
                            .font(TypeStyle.label.font)
                            .foregroundStyle(palette.ink)
                        palette.hairline.frame(height: Rule.width)
                        ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(TypeStyle.body.font)
                                .foregroundStyle(palette.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                    }
                }
            }
            .padding(.top, CardSpacing.block)

            Spacer(minLength: 0)
            Text("Cali Care · Not medical advice.")
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
        }
        .padding(Spacing.margin)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(palette.paper)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .light)
    }
}

/// The caregiver card as a picture (1800 × 2250) or a one-page PDF.
public enum CaregiverCardRenderer {
    @MainActor
    public static func image(for card: CaregiverCard) -> UIImage? {
        FontRegistry.registerAll()
        let renderer = ImageRenderer(content: CaregiverCardView(card: card))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// US Letter, the card centered on paper.
    @MainActor
    public static func pdfData(for card: CaregiverCard) -> Data {
        FontRegistry.registerAll()
        let page = CGSize(width: 612, height: 792)
        let output = NSMutableData()
        var box = CGRect(origin: .zero, size: page)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return Data() }
        let renderer = ImageRenderer(content: CaregiverCardView(card: card).frame(width: page.width, height: page.height).background(Palette.day.paper))
        renderer.proposedSize = ProposedViewSize(page)
        renderer.render { _, render in
            context.beginPDFPage(nil)
            render(context)
            context.endPDFPage()
        }
        context.closePDF()
        return output as Data
    }

    /// Temporary files named like "Cal caregiver card.png" / ".pdf".
    @MainActor
    public static func files(for card: CaregiverCard) throws -> (image: URL, pdf: URL) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(card.childName) caregiver card".replacingOccurrences(of: "/", with: "-"))
        guard let png = image(for: card)?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        let imageURL = base.appendingPathExtension("png")
        let pdfURL = base.appendingPathExtension("pdf")
        try png.write(to: imageURL, options: .atomic)
        try pdfData(for: card).write(to: pdfURL, options: .atomic)
        return (imageURL, pdfURL)
    }
}

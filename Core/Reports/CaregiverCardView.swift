import SwiftUI
import UIKit

/// The caregiver card: a phone-sized page (390 × 844 points) that fills the
/// screen when opened from a text. Day palette always, body 17 and labels 13.
public struct CaregiverCardView: View {
    public static let size = CGSize(width: 390, height: 844)

    let card: CaregiverCard
    let plan: CaregiverPlan
    let parentName: String?
    let date: Date
    private let palette = Palette.day

    public init(card: CaregiverCard, plan: CaregiverPlan = CaregiverPlan(), parentName: String? = nil, date: Date = .now) {
        self.card = card
        self.plan = plan
        self.parentName = parentName
        self.date = date
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(forLine)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.graphite)
                    .lineLimit(1)
                Spacer(minLength: Spacing.x2)
                Text("Cali Care")
                    .font(.custom(TypeStyle.displayCut, fixedSize: 15))
                    .foregroundStyle(palette.graphite)
            }
            Text("Caring for \(card.childName)")
                .font(.custom(TypeStyle.displayCut, fixedSize: 38))
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.top, Spacing.x2)

            VStack(alignment: .leading, spacing: 22) {
                if !plan.skinRoutine.isEmpty {
                    block("Skin routine, in this order") {
                        ForEach(Array(plan.skinRoutine.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                                Text("\(index + 1)").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.graphite)
                                Text(step).font(.system(size: 17)).foregroundStyle(palette.ink).lineLimit(2)
                            }
                        }
                    }
                }
                if !plan.schedule.isEmpty {
                    block("What to do when") {
                        ForEach(plan.schedule, id: \.block) { row in
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.x3) {
                                Text(row.block.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(palette.graphite)
                                    .frame(width: 74, alignment: .leading)
                                Text(row.items.joined(separator: "\n"))
                                    .font(.system(size: 17))
                                    .foregroundStyle(palette.ink)
                                    .lineLimit(5)
                            }
                        }
                    }
                }
                ForEach(card.sections, id: \.title) { section in
                    block(section.title) {
                        ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(size: 17)).foregroundStyle(palette.ink).lineLimit(3)
                        }
                    }
                }
            }
            .padding(.top, 26)

            Spacer(minLength: Spacing.x4)
            Text("Questions? Text \(parentName ?? "\(card.childName)’s parent") anytime.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.ink)
        }
        .padding(.top, 40)
        .padding(.horizontal, 28)
        .padding(.bottom, 32)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(palette.paper)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .light)
    }

    /// "For Grandma · Oct 11", or just the date.
    private var forLine: String {
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        guard let who = card.caregiver?.trimmingCharacters(in: .whitespaces), !who.isEmpty else { return day }
        return "For \(who) · \(day)"
    }

    private func block(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(palette.graphite)
            content()
        }
    }
}

/// The caregiver card as a picture (1170 × 2532) or a one-page PDF.
public enum CaregiverCardRenderer {
    @MainActor
    public static func image(for view: CaregiverCardView) -> UIImage? {
        FontRegistry.registerAll()
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// US Letter, the card centered on paper.
    @MainActor
    public static func pdfData(for view: CaregiverCardView) -> Data {
        FontRegistry.registerAll()
        let page = CGSize(width: 612, height: 792)
        let output = NSMutableData()
        var box = CGRect(origin: .zero, size: page)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return Data() }
        let renderer = ImageRenderer(content: view.frame(width: page.width, height: page.height).background(Palette.day.paper))
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
    public static func files(for view: CaregiverCardView) throws -> (image: URL, pdf: URL) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(view.card.childName) caregiver card".replacingOccurrences(of: "/", with: "-"))
        guard let png = image(for: view)?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        let imageURL = base.appendingPathExtension("png")
        let pdfURL = base.appendingPathExtension("pdf")
        try png.write(to: imageURL, options: .atomic)
        try pdfData(for: view).write(to: pdfURL, options: .atomic)
        return (imageURL, pdfURL)
    }
}

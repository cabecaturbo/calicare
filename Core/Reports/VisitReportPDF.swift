import SwiftUI

/// Draws a VisitReport as a one-page US Letter PDF (two past six weeks):
/// white paper, 48pt side margins, body 11pt and nothing under 9pt, rules at
/// least 0.75pt, and skin squares that still read printed in grayscale
/// (olive light to dark, dashed when not logged).
public enum VisitReportPDF {
    public static let pageSize = CGSize(width: 612, height: 792)

    @MainActor
    public static func data(for report: VisitReport) -> Data {
        FontRegistry.registerAll()
        let pages = pages(for: report)
        let output = NSMutableData()
        var box = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return Data() }
        for (index, page) in pages.enumerated() {
            let renderer = ImageRenderer(content: Page(footer: report.footer, number: index + 1, count: pages.count) { page })
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, render in
                context.beginPDFPage(nil)
                render(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return output as Data
    }

    /// Writes the PDF to a temporary file named like "Cal visit report Oct 11.pdf".
    @MainActor
    public static func file(for report: VisitReport) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(report.fileName.replacingOccurrences(of: "/", with: "-")).pdf")
        try data(for: report).write(to: url, options: .atomic)
        return url
    }

    @MainActor
    static func pages(for report: VisitReport) -> [AnyView] {
        let first = Array(report.weeks.prefix(VisitReport.weeksOnFirstPage))
        let rest = Array(report.weeks.dropFirst(VisitReport.weeksOnFirstPage))
        if rest.isEmpty {
            return [AnyView(VStack(alignment: .leading, spacing: 18) {
                Top(report: report)
                SkinTable(weeks: first)
                Columns(report: report)
            })]
        }
        return [
            AnyView(VStack(alignment: .leading, spacing: 18) {
                Top(report: report)
                SkinTable(weeks: first)
            }),
            AnyView(VStack(alignment: .leading, spacing: 18) {
                SkinTable(weeks: rest, continued: true)
                Columns(report: report)
            }),
        ]
    }
}

// MARK: - Pieces

private let palette = Palette.day
private let serif = "NewsreaderDisplay-Medium"
private let serifRegular = "NewsreaderDisplay-Regular"

private struct Page<Content: View>: View {
    let footer: String
    let number: Int
    let count: Int
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.bottom, 32)
            .clipped()
            .overlay(alignment: .bottom) {
                VStack(spacing: 6) {
                    palette.graphite.frame(height: 0.75)
                    HStack {
                        Text(footer)
                        Spacer()
                        Text("Page \(number) of \(count)")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(palette.graphite)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 44)
            .frame(width: VisitReportPDF.pageSize.width, height: VisitReportPDF.pageSize.height, alignment: .topLeading)
            .background(Color.white)
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .large)
    }
}

private struct Top: View {
    let report: VisitReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cali Care").font(.custom(serif, fixedSize: 14)).foregroundStyle(palette.graphite)
                Spacer()
                if let header = report.header {
                    Text(header).font(.system(size: 11)).foregroundStyle(palette.graphite)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(report.title).font(.custom(serif, fixedSize: 27)).foregroundStyle(palette.ink)
                Text(report.subtitle).font(.system(size: 11)).foregroundStyle(palette.graphite)
            }
            .padding(.top, 4)
            Text(report.summary)
                .font(.custom(serifRegular, fixedSize: 16.5))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.custom(serif, fixedSize: 14)).foregroundStyle(palette.ink)
    }
}

private struct Swatch: View {
    let skin: SkinToday?
    var size: CGFloat = 27
    var faded = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        Group {
            if let skin {
                shape.fill(palette.color(for: skin)).overlay(shape.strokeBorder(palette.graphite, lineWidth: 0.75))
            } else {
                shape.strokeBorder(palette.graphite, style: StrokeStyle(lineWidth: 0.75, dash: [2.5, 2]))
            }
        }
        .frame(width: size, height: size)
        .opacity(faded ? 0 : 1)
    }
}

private struct SkinTable: View {
    let weeks: [VisitReport.Week]
    var continued = false

    private let numberWidth: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: continued ? "Skin, day by day (continued)" : "Skin, day by day")
            HStack(spacing: 0) {
                Text("Week of").frame(width: 56, alignment: .leading)
                Spacer()
                Text("Itchy wake-ups").frame(width: numberWidth, alignment: .trailing)
                Text("Good nights").frame(width: numberWidth, alignment: .trailing)
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(palette.graphite)
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(alignment: .leading, spacing: 3) {
                    if week.planStarts {
                        HStack(spacing: 6) {
                            palette.ink.frame(height: 1)
                            Text("Plan starts").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(palette.ink)
                        }
                    }
                    HStack(spacing: 0) {
                        Text(week.startLabel).font(.system(size: 11)).foregroundStyle(palette.ink)
                            .frame(width: 56, alignment: .leading)
                        HStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { index in
                                Swatch(skin: week.skin[index], faded: !week.inRange[index])
                            }
                        }
                        Spacer()
                        Text("\(week.itchyWakeUps)").frame(width: numberWidth, alignment: .trailing)
                        Text("\(week.goodNights) of \(week.nights)").frame(width: numberWidth, alignment: .trailing)
                    }
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(palette.ink)
                }
            }
            if !continued { Legend().padding(.top, 2) }
        }
    }
}

private struct Legend: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(SkinToday.allCases, id: \.self) { skin in
                HStack(spacing: 4) {
                    Swatch(skin: skin, size: 11)
                    Text(skin.title)
                }
            }
            HStack(spacing: 4) {
                Swatch(skin: nil, size: 11)
                Text("Not logged")
            }
        }
        .font(.system(size: 9.5))
        .foregroundStyle(palette.graphite)
    }
}

private struct Columns: View {
    let report: VisitReport

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Following the plan")
                if report.following.isEmpty {
                    Text("No plan steps started yet.").font(.system(size: 11)).foregroundStyle(palette.graphite)
                }
                ForEach(Array(report.following.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.name).font(.system(size: 11)).foregroundStyle(palette.ink)
                            if let often = line.often {
                                Text(often).font(.system(size: 9.5)).foregroundStyle(palette.graphite)
                            }
                        }
                        Spacer(minLength: 6)
                        Text(line.done).font(.system(size: 11).monospacedDigit()).foregroundStyle(palette.ink)
                    }
                    .lineLimit(2)
                }
                if !report.notStarted.isEmpty {
                    Text("Not started yet: " + report.notStarted.joined(separator: ", "))
                        .font(.system(size: 9.5))
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Notes from home")
                if report.notes.isEmpty {
                    Text("No notes in these weeks.").font(.system(size: 11)).foregroundStyle(palette.graphite)
                }
                ForEach(Array(report.notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 6) {
                        Swatch(skin: note.skin, size: 10).padding(.top, 2)
                        Text("\(Text(note.date).foregroundStyle(palette.graphite)) \(note.text)")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.ink)
                            .lineLimit(3)
                    }
                }
                if let questions = report.questions {
                    SectionLabel(text: "Questions for the visit").padding(.top, 8)
                    Text(questions)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.ink)
                        .lineLimit(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

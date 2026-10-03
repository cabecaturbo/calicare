import Charts
import SwiftUI

/// Draws a DoctorReport as a multi-page US Letter PDF: summary and trends,
/// day by day, notes, then the full log table. Every page carries the child,
/// the dates, and "Not medical advice. Logged by parent." White pages (they
/// get printed), ink text, indigo only in the charts.
public enum DoctorReportPDF {
    public static let pageSize = CGSize(width: 612, height: 792)
    /// About 24pt a row in the ~560pt between the page title and the footer.
    static let dayRowsPerPage = 22
    static let logRowsPerPage = 22
    static let notesPerPage = 9

    @MainActor
    public static func data(for report: DoctorReport) -> Data {
        FontRegistry.registerAll()
        let pages = pages(for: report)
        let output = NSMutableData()
        var box = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return Data() }

        for (index, page) in pages.enumerated() {
            let renderer = ImageRenderer(content: PageFrame(footer: report.footer, number: index + 1, count: pages.count) { page })
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

    /// Writes the PDF to a temporary file named like "Cal care log Aug 31 – Sep 27, 2026.pdf".
    @MainActor
    public static func file(for report: DoctorReport) throws -> URL {
        let name = "\(report.child.name) care log \(report.dateRange)".replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        try data(for: report).write(to: url, options: .atomic)
        return url
    }

    @MainActor
    static func pages(for report: DoctorReport) -> [AnyView] {
        var pages: [AnyView] = [AnyView(SummaryPage(report: report))]
        for chunk in report.days.chunked(dayRowsPerPage) {
            pages.append(AnyView(DaysPage(days: chunk)))
        }
        if !report.notes.isEmpty {
            for chunk in report.notes.chunked(notesPerPage) {
                pages.append(AnyView(NotesPage(notes: chunk)))
            }
        }
        for chunk in report.rows.chunked(logRowsPerPage) {
            pages.append(AnyView(LogTablePage(rows: chunk)))
        }
        return pages
    }
}

// MARK: - Page frame

private let palette = Palette.day

private struct PageFrame<Content: View>: View {
    let footer: String
    let number: Int
    let count: Int
    @ViewBuilder let content: Content

    /// The footer is pinned to the bottom, so no amount of content can push it off the page.
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.bottom, 40)
            .clipped()
            .overlay(alignment: .bottom) {
                VStack(spacing: Spacing.x2) {
                    palette.hairline.frame(height: Rule.width)
                    HStack {
                        Text(footer)
                        Spacer()
                        Text("Page \(number) of \(count)")
                    }
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(palette.graphite)
                }
            }
            .padding(48)
            .frame(width: DoctorReportPDF.pageSize.width, height: DoctorReportPDF.pageSize.height, alignment: .topLeading)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .light)
    }
}

private struct PageTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(title)
                .font(TypeStyle.title.font)
                .foregroundStyle(palette.ink)
            if let detail {
                Text(detail)
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(palette.graphite)
            }
            palette.ink.frame(height: Rule.width).padding(.top, Spacing.x2)
        }
        .padding(.bottom, Spacing.x4)
    }
}

// MARK: - Summary and trends

private struct SummaryPage: View {
    let report: DoctorReport

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(
                title: "Care log for \(report.child.name)",
                detail: "\(report.dateRange). Counts of what a parent logged in CaliCare. Skin is the parent's daily answer: calm, a little itchy, flaring, or very rough."
            )
            VStack(spacing: 0) {
                stat("Days with logs", "\(report.daysWithLogs) of \(report.days.count)")
                stat("Nights rated", "\(report.goodNights) good, \(report.okayNights) okay, \(report.roughNights) rough")
                stat("Itchy wake-ups at night", "\(report.itchyWakeUps)")
                stat("Itchy spells in the day", "\(report.daytimeItches)")
                stat("Flares", "\(report.flares)")
                stat("Days with a routine done", "\(report.routineDays)")
                stat("Bowel movements", "\(report.bowelMovements)")
                if !report.moods.isEmpty {
                    stat("Moods logged", report.moods.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
                }
            }

            Text("Itchy wake-ups per night")
                .font(TypeStyle.control.font)
                .foregroundStyle(palette.ink)
                .padding(.top, Spacing.margin)
            Chart(report.days, id: \.day) { day in
                BarMark(x: .value("Night", day.day.noon()), y: .value("Wake-ups", day.itchyWakeUps))
                    .foregroundStyle(palette.indigo)
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
            .frame(height: 120)
            .padding(.top, Spacing.x2)

            Text("Night rating (lower is calmer)")
                .font(TypeStyle.control.font)
                .foregroundStyle(palette.ink)
                .padding(.top, Spacing.x4)
            Chart(report.days.filter { $0.night != nil }, id: \.day) { day in
                PointMark(x: .value("Night", day.day.noon()), y: .value("Level", day.night?.rawValue ?? 0))
                    .foregroundStyle(palette.indigo)
            }
            .chartYScale(domain: 0...2)
            .chartYAxis {
                AxisMarks(values: [0, 1, 2]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text(["Calm", "Medium", "Hard"][value.as(Int.self) ?? 0]) }
                }
            }
            .frame(height: 90)
            .padding(.top, Spacing.x2)
        }
        .font(TypeStyle.meta.font)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(TypeStyle.control.font).foregroundStyle(palette.ink)
            Spacer()
            Text(value).font(TypeStyle.meta.font).monospacedDigit().foregroundStyle(palette.ink)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }
}

// MARK: - Day by day

private struct DaysPage: View {
    let days: [DoctorReport.Day]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "Day by day", detail: "A day runs 7 PM to 7 PM, so each night belongs to the morning it ends.")
            TableRow(cells: ["Day", "Night", "Skin", "Bowel movements"], widths: [120, 110, 110, nil], header: true)
            ForEach(days, id: \.day) { day in
                TableRow(
                    cells: [day.label, Self.words(day.night), day.skin?.words ?? "not answered",
                            day.bowelMovements.isEmpty ? "" : day.bowelMovements.joined(separator: ", ")],
                    widths: [120, 110, 110, nil]
                )
            }
        }
    }

    static func words(_ level: CareLevel?) -> String {
        switch level {
        case .low?: "calm"
        case .medium?: "medium"
        case .high?: "hard"
        case nil: "not logged"
        }
    }
}

// MARK: - Notes

private struct NotesPage: View {
    let notes: [DoctorReport.Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "Notes")
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(note.date), \(note.time) · \(note.what) · \(note.loggedBy)")
                        .font(TypeStyle.meta.font)
                        .foregroundStyle(palette.graphite)
                    Text(note.note ?? "")
                        .font(TypeStyle.meta.font)
                        .foregroundStyle(palette.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
            }
        }
    }
}

// MARK: - Full log

private struct LogTablePage: View {
    let rows: [DoctorReport.Row]
    static let widths: [CGFloat?] = [56, 64, 140, nil, 64, 70]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageTitle(title: "Every log")
            TableRow(cells: ["Day", "Time", "What", "Note", "By", "From"], widths: Self.widths, header: true)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                TableRow(cells: [row.date, row.time, row.what, row.note ?? "", row.loggedBy, row.source], widths: Self.widths)
            }
        }
    }
}

private struct TableRow: View {
    let cells: [String]
    let widths: [CGFloat?]
    var header = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                let text = Text(cell)
                    .font(header ? TypeStyle.control.font : TypeStyle.meta.font)
                    .foregroundStyle(header ? palette.ink : palette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let width = widths[index] {
                    text.frame(width: width, alignment: .leading)
                } else {
                    text.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { (header ? palette.ink : palette.hairline).frame(height: Rule.width) }
    }
}

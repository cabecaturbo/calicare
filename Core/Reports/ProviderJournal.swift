import Foundation
import SwiftUI

/// The daily journal in the format providers ask for (prompt 4.7): per day,
/// what changed, rash and itch, bowel movements, sleep, mood, and notes.
/// Only what was logged; empty days are left out. Ends "Not medical advice".
public struct ProviderJournal: Equatable, Sendable {
    public struct Day: Equatable, Sendable {
        public let day: CareDay
        public let changes: [String]
        public let skinAndItch: String?
        public let bowel: String?
        public let sleep: String?
        public let mood: String?
        public let notes: [String]
    }

    public let childName: String
    public let range: DoctorReport.Range
    public let days: [Day]

    public static let headers = ["Date", "Changes", "Rash and itch", "Bowel movements", "Sleep", "Mood", "Notes"]

    public init(childName: String, range: DoctorReport.Range, events: [LogEntry], changes: [CareChange],
                calendar: Calendar = .autoupdatingCurrent) {
        self.childName = childName
        self.range = range
        days = range.days(calendar: calendar).compactMap { careDay in
            let mine = events.filter { careDay.contains($0.timestamp, calendar: calendar) }
            let summary = DaySummary(day: careDay, events: mine, calendar: calendar)
            let interval = careDay.interval(calendar: calendar)
            let changed = changes.filter { interval.contains($0.date) }.map(\.text)

            var skin: [String] = []
            if let answer = summary.skinToday { skin.append("Skin \(answer.words)") }
            let itches = mine.filter { $0.type == .itchEpisode }.count
            if itches > 0 { skin.append(itches == 1 ? "1 itchy spell" : "\(itches) itchy spells") }
            for flare in mine.filter({ $0.type == .flare }) {
                skin.append(flare.bodyAreas.isEmpty ? "Flare" : "Flare (\(flare.bodyAreas.map(\.words).joined(separator: ", ")))")
            }

            let bowels = mine.filter { $0.type == .bowelMovement }
            let bowel: String? = bowels.isEmpty ? nil : ([String(bowels.count)] + bowels.compactMap { entry in
                if case .bowel(let kind)? = entry.value { kind == .none ? "none" : kind.rawValue } else { nil }
            }).joined(separator: " · ")

            var sleep: [String] = []
            if let rating = summary.nightRating { sleep.append("\(rating.rawValue.capitalized) night") }
            if summary.nightItchEpisodes > 0 {
                sleep.append(summary.nightItchEpisodes == 1 ? "1 itchy wake-up" : "\(summary.nightItchEpisodes) itchy wake-ups")
            }

            let moods = mine.compactMap { entry -> String? in
                if case .mood(let mood)? = entry.value { mood.rawValue } else { nil }
            }
            let notes = mine.filter { $0.type == .note }.compactMap(\.note)

            let day = Day(day: careDay, changes: changed, skinAndItch: skin.isEmpty ? nil : skin.joined(separator: " · "),
                          bowel: bowel, sleep: sleep.isEmpty ? nil : sleep.joined(separator: " · "),
                          mood: moods.isEmpty ? nil : moods.joined(separator: ", "), notes: notes)
            let isEmpty = changed.isEmpty && skin.isEmpty && bowel == nil && sleep.isEmpty && moods.isEmpty && notes.isEmpty
            return isEmpty ? nil : day
        }
    }

    /// One row per day, plus a last line saying it isn't medical advice.
    public func csv(calendar: Calendar = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let rows = days.map { day in
            [formatter.string(from: day.day.noon(calendar: calendar)), day.changes.joined(separator: "; "), day.skinAndItch ?? "",
             day.bowel ?? "", day.sleep ?? "", day.mood ?? "", day.notes.joined(separator: "; ")]
        }
        let lines = ([Self.headers] + rows + [["\(childName) · Cali Care · Not medical advice. Logged by parent."]])
            .map { $0.map(LogExport.escape).joined(separator: ",") }
        return lines.joined(separator: "\r\n") + "\r\n"
    }
}

/// The journal as a PDF: a block per day, about six days a page.
public enum ProviderJournalPDF {
    static let daysPerPage = 6

    @MainActor
    public static func data(for journal: ProviderJournal) -> Data {
        FontRegistry.registerAll()
        let page = DoctorReportPDF.pageSize
        let output = NSMutableData()
        var box = CGRect(origin: .zero, size: page)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else { return Data() }
        let chunks = journal.days.isEmpty ? [[]] : journal.days.chunked(daysPerPage)
        for (index, days) in chunks.enumerated() {
            let renderer = ImageRenderer(content: JournalPage(journal: journal, days: days, number: index + 1, count: chunks.count))
            renderer.proposedSize = ProposedViewSize(page)
            renderer.render { _, render in
                context.beginPDFPage(nil)
                render(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return output as Data
    }

    /// Temporary CSV and PDF files named like "Cal journal Sep 1 – 30, 2026".
    @MainActor
    public static func files(for journal: ProviderJournal) throws -> (csv: URL, pdf: URL) {
        let report = DoctorReport(child: ChildInfo(id: UUID(), name: journal.childName, birthDate: nil, colorTag: "", isActive: true),
                                  range: journal.range, events: [])
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(journal.childName) journal \(report.dateRange)".replacingOccurrences(of: "/", with: "-"))
        let csv = base.appendingPathExtension("csv")
        let pdf = base.appendingPathExtension("pdf")
        try Data(journal.csv().utf8).write(to: csv, options: .atomic)
        try data(for: journal).write(to: pdf, options: .atomic)
        return (csv, pdf)
    }
}

private struct JournalPage: View {
    let journal: ProviderJournal
    let days: [ProviderJournal.Day]
    let number: Int
    let count: Int
    private let palette = Palette.day

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            if number == 1 {
                Text("\(journal.childName)’s daily journal")
                    .font(TypeStyle.title.font)
                    .foregroundStyle(palette.ink)
                Text("Changes, rash and itch, bowel movements, sleep, and mood, as logged. Days with nothing logged are left out.")
                    .font(TypeStyle.meta.font)
                    .foregroundStyle(palette.graphite)
            }
            if days.isEmpty {
                Text("Nothing was logged in these dates.").font(TypeStyle.body.font).foregroundStyle(palette.ink)
            }
            ForEach(days, id: \.day) { day in
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.day.noon().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(TypeStyle.label.font)
                        .foregroundStyle(palette.ink)
                    palette.hairline.frame(height: Rule.width)
                    line("Changes", day.changes.isEmpty ? nil : day.changes.joined(separator: "; "))
                    line("Rash and itch", day.skinAndItch)
                    line("Bowel movements", day.bowel)
                    line("Sleep", day.sleep)
                    line("Mood", day.mood)
                    line("Notes", day.notes.isEmpty ? nil : day.notes.joined(separator: "; "))
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text("\(journal.childName) · Cali Care · Not medical advice. Logged by parent.")
                Spacer()
                Text("Page \(number) of \(count)")
            }
            .font(TypeStyle.meta.font)
            .foregroundStyle(palette.graphite)
        }
        .padding(48)
        .frame(width: DoctorReportPDF.pageSize.width, height: DoctorReportPDF.pageSize.height, alignment: .topLeading)
        .background(palette.paper)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func line(_ label: String, _ value: String?) -> some View {
        if let value {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.x2) {
                Text(label).font(TypeStyle.meta.font).foregroundStyle(palette.graphite).frame(width: 110, alignment: .leading)
                Text(value).font(TypeStyle.meta.font).foregroundStyle(palette.ink).lineLimit(3)
            }
        }
    }
}

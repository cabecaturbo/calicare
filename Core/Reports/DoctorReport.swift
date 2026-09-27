import Foundation
import SwiftData

/// Everything logged for one child over a date range, laid out for a
/// provider. Counts only; no conclusions. Pure once built.
public struct DoctorReport: Equatable, Sendable {
    public struct Range: Equatable, Sendable {
        public let first: CareDay
        public let last: CareDay

        public init(first: CareDay, last: CareDay) {
            (self.first, self.last) = first <= last ? (first, last) : (last, first)
        }

        /// Since the last visit if there was one, otherwise the last 4 weeks, ending today.
        public static func standard(lastVisit: Date?, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Range {
            let today = CareDay.containing(now, calendar: calendar)
            if let lastVisit, lastVisit < now {
                return Range(first: CareDay.containing(lastVisit, calendar: calendar), last: today)
            }
            return Range(first: today.adding(days: -27, calendar: calendar), last: today)
        }

        public func days(calendar: Calendar = .autoupdatingCurrent) -> [CareDay] {
            var result: [CareDay] = []
            var day = first
            while day <= last {
                result.append(day)
                day = day.adding(days: 1, calendar: calendar)
            }
            return result
        }
    }

    /// One row of the full log table.
    public struct Row: Equatable, Sendable {
        public let date: String
        public let time: String
        public let what: String
        public let note: String?
        public let loggedBy: String
        public let source: String
    }

    /// One day, for the trend chart and the skin list. Nil levels mean nothing was logged.
    public struct Day: Equatable, Sendable {
        public let day: CareDay
        public let label: String
        public let itchyWakeUps: Int
        public let night: CareLevel?
        public let skin: CareLevel?
        public let bowelMovements: [String]
    }

    public let child: ChildInfo
    public let range: Range
    public let dateRange: String
    public let days: [Day]
    public let daysWithLogs: Int
    public let goodNights: Int
    public let okayNights: Int
    public let roughNights: Int
    public let itchyWakeUps: Int
    public let daytimeItches: Int
    public let flares: Int
    public let routineDays: Int
    public let bowelMovements: Int
    public let moods: [String: Int]
    public let notes: [Row]
    public let rows: [Row]

    public static let footerNote = "Not medical advice. Logged by parent."
}

extension DoctorReport {
    public init(
        child: ChildInfo,
        range: Range,
        events: [LogEntry],
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        let phrases = LogPhrases(calendar: calendar, locale: locale)
        let mine = events
            .filter { $0.childID == child.id && range.first.interval(calendar: calendar).start <= $0.timestamp
                && $0.timestamp < range.last.interval(calendar: calendar).end }
            .sorted { $0.timestamp < $1.timestamp }
        let summaries = range.days(calendar: calendar).map { DaySummary(day: $0, events: mine, calendar: calendar) }
        let logged = summaries.filter { $0.totalEvents > 0 }

        let dayFormat = Self.formatter("EEE MMM d", calendar: calendar, locale: locale)
        let dateFormat = Self.formatter("MMM d", calendar: calendar, locale: locale)

        self.child = child
        self.range = range
        dateRange = "\(dateFormat.string(from: range.first.noon(calendar: calendar))) – "
            + Self.formatter("MMM d, yyyy", calendar: calendar, locale: locale).string(from: range.last.noon(calendar: calendar))
        days = summaries.map { summary in
            let week = WeekDay(summary: summary)
            return Day(
                day: summary.day,
                label: dayFormat.string(from: summary.day.noon(calendar: calendar)),
                itchyWakeUps: summary.nightItchEpisodes,
                night: week.night,
                skin: week.skin,
                bowelMovements: summary.bowelMovements.map(\.rawValue)
            )
        }
        daysWithLogs = logged.count
        goodNights = logged.filter { $0.nightRating == .good }.count
        okayNights = logged.filter { $0.nightRating == .okay }.count
        roughNights = logged.filter { $0.nightRating == .rough }.count
        itchyWakeUps = logged.reduce(0) { $0 + $1.nightItchEpisodes }
        daytimeItches = logged.reduce(0) { $0 + $1.daytimeItchEpisodes }
        flares = logged.reduce(0) { $0 + $1.flares }
        routineDays = logged.filter { $0.routinesDone > 0 }.count
        bowelMovements = logged.reduce(0) { $0 + $1.bowelMovementCount }
        moods = mine.reduce(into: [:]) { counts, entry in
            if case .mood(let mood)? = entry.value { counts[mood.rawValue.capitalized, default: 0] += 1 }
        }

        let rows = mine.map { entry in
            Row(
                date: dateFormat.string(from: CareDay.containing(entry.timestamp, calendar: calendar).noon(calendar: calendar)),
                time: phrases.time(entry.timestamp),
                what: phrases.title(for: entry),
                note: entry.note,
                loggedBy: entry.loggedBy,
                source: entry.source.rawValue.capitalized
            )
        }
        self.rows = rows
        notes = zip(mine, rows).filter { $0.0.note != nil }.map(\.1)
    }

    /// Reads the range from the store and builds the report.
    public static func load(
        child: ChildInfo,
        range: Range,
        container: ModelContainer,
        calendar: Calendar = .autoupdatingCurrent
    ) async throws -> DoctorReport {
        let events = try await LogStore(modelContainer: container, calendar: calendar)
            .events(from: range.first, through: range.last, child: child.id)
        return DoctorReport(child: child, range: range, events: events, calendar: calendar)
    }

    /// "Cal · Aug 31 – Sep 27, 2026 · Not medical advice. Logged by parent."
    public var footer: String {
        "\(child.name) · \(dateRange) · \(Self.footerNote)"
    }

    private static func formatter(_ template: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

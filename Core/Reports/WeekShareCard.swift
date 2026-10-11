import Foundation
import SwiftData

/// What the "Share this week" picture shows: a name, the dates, the week's
/// headline, one square per day for skin, and up to two short lines.
/// Built from the same report as Progress, so nothing is worded twice.
public struct WeekShareCard: Equatable, Sendable {
    public struct Day: Equatable, Sendable, Identifiable {
        public let day: CareDay
        /// "Mon", "Tue"…
        public let label: String
        /// The roughest answer that day; nil when skin wasn't answered.
        public let skin: SkinToday?

        public var id: CareDay { day }
    }

    public let childName: String
    /// "Sep 21–27", or "Sep 29–Oct 5" across months.
    public let rangeLabel: String
    public let headline: String
    /// Oldest first.
    public let days: [Day]
    /// "4 of 7 good nights." Nil when no night was rated.
    public let nightsLine: String?
    /// The short worth-watching line, if any.
    public let worthWatching: String?

    public init(
        childName: String,
        rangeLabel: String,
        headline: String,
        days: [Day],
        nightsLine: String?,
        worthWatching: String?
    ) {
        self.childName = childName
        self.rangeLabel = rangeLabel
        self.headline = headline
        self.days = days
        self.nightsLine = nightsLine
        self.worthWatching = worthWatching
    }

    /// `events` are the week's logs (more is fine; others are ignored).
    public init(
        report: WeeklyReport,
        events: [LogEntry],
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .current
    ) {
        let weekday = DateFormatter()
        weekday.locale = locale
        weekday.calendar = calendar
        weekday.timeZone = calendar.timeZone
        weekday.setLocalizedDateFormatFromTemplate("EEE")
        let mine = events.filter { $0.childID == report.child.id }

        self.init(
            childName: report.child.name,
            rangeLabel: Self.rangeLabel(ending: report.weekEnding, calendar: calendar, locale: locale),
            headline: report.headline.text,
            days: report.days.map { day in
                Day(
                    day: day.day,
                    label: weekday.string(from: day.day.noon(calendar: calendar)),
                    skin: Self.roughest(on: day.day, in: mine, calendar: calendar)
                )
            },
            nightsLine: report.ratedNights > 0 ? "\(report.goodNights) of 7 good nights." : nil,
            worthWatching: report.worthWatchingShort
        )
    }

    /// The roughest skin answer logged for `day`.
    static func roughest(on day: CareDay, in events: [LogEntry], calendar: Calendar) -> SkinToday? {
        events
            .filter { day.contains($0.timestamp, calendar: calendar) }
            .compactMap { entry -> SkinToday? in
                if case .skin(let answer)? = entry.value { return answer }
                return nil
            }
            .max { $0.step < $1.step }
    }

    /// "Sep 21–27", or "Sep 29–Oct 5" when the week crosses a month.
    public static func rangeLabel(ending last: CareDay, calendar: Calendar = .autoupdatingCurrent, locale: Locale = .current) -> String {
        let first = last.adding(days: -6, calendar: calendar)
        let month = DateFormatter()
        month.locale = locale
        month.calendar = calendar
        month.timeZone = calendar.timeZone
        month.setLocalizedDateFormatFromTemplate("MMM")
        let start = "\(month.string(from: first.noon(calendar: calendar))) \(first.day)"
        let end = first.month == last.month
            ? "\(last.day)"
            : "\(month.string(from: last.noon(calendar: calendar))) \(last.day)"
        return "\(start)–\(end)"
    }

    /// Reads the week (and last week, for the headline) from the store.
    public static func load(
        child: ChildInfo,
        weekEnding: CareDay,
        container: ModelContainer,
        calendar: Calendar = .autoupdatingCurrent
    ) async throws -> WeekShareCard {
        let events = try await LogStore(modelContainer: container, calendar: calendar).events(
            from: weekEnding.adding(days: -13, calendar: calendar),
            through: weekEnding,
            child: child.id
        )
        let report = WeeklyReport(child: child, weekEnding: weekEnding, events: events, calendar: calendar)
        return WeekShareCard(report: report, events: events, calendar: calendar)
    }
}

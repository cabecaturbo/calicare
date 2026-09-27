import Foundation
import SwiftData

extension WeeklyReport {
    /// Reads this week and last from the store and builds the report.
    public static func load(
        child: ChildInfo,
        weekEnding: CareDay,
        container: ModelContainer,
        calendar: Calendar = .autoupdatingCurrent
    ) async throws -> WeeklyReport {
        let events = try await LogStore(modelContainer: container, calendar: calendar).events(
            from: weekEnding.adding(days: -13, calendar: calendar),
            through: weekEnding,
            child: child.id
        )
        return WeeklyReport(child: child, weekEnding: weekEnding, events: events, calendar: calendar)
    }

    /// "Sep 20 – 26", or "Sep 27 – Oct 3" across months.
    public func dateRange(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .current) -> String {
        let first = weekEnding.adding(days: -6, calendar: calendar)
        let last = weekEnding
        let month = DateFormatter()
        month.locale = locale
        month.calendar = calendar
        month.timeZone = calendar.timeZone
        month.setLocalizedDateFormatFromTemplate("MMM")
        let start = "\(month.string(from: first.noon(calendar: calendar))) \(first.day)"
        let end = first.month == last.month
            ? "\(last.day)"
            : "\(month.string(from: last.noon(calendar: calendar))) \(last.day)"
        return "\(start) – \(end)"
    }
}

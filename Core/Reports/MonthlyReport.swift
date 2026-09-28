import Foundation
import SwiftData

/// How one child's calendar month went, for Progress › Month. Built like the
/// weekly report: days with nothing logged are left out of every comparison,
/// and a partial month (this one) is compared by averages, never totals.
public struct MonthlyReport: Equatable, Sendable {
    public let child: ChildInfo
    public let year: Int
    public let month: Int
    /// Care days of the month, oldest first, through `through` for this month.
    public let days: [WeekDay]
    public let daysWithLogs: Int
    public let goodNights: Int
    public let itchyWakeUps: Int
    public let flares: Int
    public let headline: Headline
    public let worthWatching: String?

    /// Below this many logged days, there's no summary (or no comparison).
    public static let minimumDays = 7

    public enum Headline: Equatable, Sendable {
        case calmer, harder, aboutTheSame, firstMonth, notEnoughLogs

        public var text: String {
            switch self {
            case .calmer: "A calmer month"
            case .harder: "A harder month"
            case .aboutTheSame: "About the same as last month"
            case .firstMonth: "A first month of logs"
            case .notEnoughLogs: "Not enough logs yet for a summary"
            }
        }
    }
}

extension MonthlyReport {
    /// `events` should cover this month and the one before. `through` cuts off
    /// the current month at today, so future days aren't shown.
    public init(
        child: ChildInfo,
        year: Int,
        month: Int,
        through: CareDay,
        events: [LogEntry],
        calendar: Calendar = .autoupdatingCurrent
    ) {
        let mine = events.filter { $0.childID == child.id }
        let (lastYear, lastMonth) = Self.previous(year, month)
        let this = Week(days: Self.days(year, month, through: through, calendar: calendar), events: mine, calendar: calendar)
        let last = Week(days: Self.days(lastYear, lastMonth, through: through, calendar: calendar), events: mine, calendar: calendar)
        let comparable = last.logged.count >= Self.minimumDays

        self.child = child
        self.year = year
        self.month = month
        days = this.days
        daysWithLogs = this.logged.count
        goodNights = this.logged.filter { $0.nightRating == .good }.count
        itchyWakeUps = this.itchyWakeUps
        flares = this.flares

        if this.logged.count < Self.minimumDays {
            headline = .notEnoughLogs
            worthWatching = nil
        } else if !comparable {
            headline = .firstMonth
            worthWatching = nil
        } else {
            let line = Self.worthWatching(this, last)
            let compared: Headline = switch WeeklyReport.compare(this, with: last) {
            case .calmer: .calmer
            case .harder: .harder
            default: .aboutTheSame
            }
            headline = compared == .calmer && line != nil ? .aboutTheSame : compared
            worthWatching = line
        }
    }

    /// Reads this month and last from the store and builds the report.
    public static func load(
        child: ChildInfo,
        year: Int,
        month: Int,
        now: Date = .now,
        container: ModelContainer,
        calendar: Calendar = .autoupdatingCurrent
    ) async throws -> MonthlyReport {
        let today = CareDay.containing(now, calendar: calendar)
        let (lastYear, lastMonth) = previous(year, month)
        let first = CareDay(year: lastYear, month: lastMonth, day: 1)
        let events = try await LogStore(modelContainer: container, calendar: calendar).events(from: first, through: today, child: child.id)
        return MonthlyReport(child: child, year: year, month: month, through: today, events: events, calendar: calendar)
    }

    /// "September 2026".
    public func title(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: CareDay(year: year, month: month, day: 15).noon(calendar: calendar))
    }

    /// The doctor report range for this month.
    public var range: DoctorReport.Range? {
        guard let first = days.first?.day, let last = days.last?.day else { return nil }
        return DoctorReport.Range(first: first, last: last)
    }

    static func previous(_ year: Int, _ month: Int) -> (Int, Int) {
        month == 1 ? (year - 1, 12) : (year, month - 1)
    }

    /// The month's care days, stopping at `through`.
    static func days(_ year: Int, _ month: Int, through: CareDay, calendar: Calendar) -> [CareDay] {
        var result: [CareDay] = []
        var day = CareDay(year: year, month: month, day: 1)
        while day.month == month, day <= through {
            result.append(day)
            day = day.adding(days: 1, calendar: calendar)
        }
        return result
    }

    /// Per logged day, so a partial month compares fairly with a full one.
    static func worthWatching(_ this: Week, _ last: Week) -> String? {
        func rate(_ count: Int, _ week: Week) -> Double { Double(count) / Double(max(week.logged.count, 1)) }
        if rate(this.itchyWakeUps, this) - rate(last.itchyWakeUps, last) >= 0.5 { return "Itchy wake-ups went up this month." }
        if rate(this.roughNights, this) - rate(last.roughNights, last) >= 0.2 { return "More rough nights this month." }
        if rate(this.flares, this) - rate(last.flares, last) >= 0.2 { return "More flares this month." }
        return nil
    }
}

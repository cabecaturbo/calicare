import Foundation

/// Today's logs, grouped by one boundary: night is 7 PM to 7 AM (the care
/// day's night, and when night colors come on). By day the list shows
/// "Today" (since 7 AM) and then "Last night"; at night, only "Tonight".
public struct TodayGroups: Equatable, Sendable {
    /// True from 7 PM to 7 AM.
    public let isNight: Bool
    /// "Today" by day, "Tonight" at night. Newest first.
    public let current: [LogEntry]
    /// By day only: last night's logs, newest first. Empty at night.
    public let lastNight: [LogEntry]

    public var currentTitle: String { isNight ? "Tonight" : "Today" }

    /// `entries` are the care day's logs, newest first.
    public init(entries: [LogEntry], day: CareDay, now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let night = day.nightInterval(calendar: calendar)
        let isNight = now >= night.start && now < night.end
        let inNight = entries.filter { $0.timestamp >= night.start && $0.timestamp < night.end }
        let inDay = entries.filter { $0.timestamp >= night.end }
        self.isNight = isNight
        current = isNight ? inNight : inDay
        lastNight = isNight ? [] : inNight
    }
}

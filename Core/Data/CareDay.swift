import Foundation

/// A care day runs 7 PM to 7 PM, so a night belongs to the morning it ends.
/// Anything logged from 7 PM on counts toward the next calendar date.
public struct CareDay: Hashable, Sendable, Comparable, CustomStringConvertible {
    public static let nightStartHour = 19
    public static let morningHour = 7

    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The care day a moment belongs to, in the calendar's time zone.
    public static func containing(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> CareDay {
        let hour = calendar.component(.hour, from: date)
        let anchor = hour >= nightStartHour
            ? calendar.date(byAdding: .day, value: 1, to: date) ?? date
            : date
        let parts = calendar.dateComponents([.year, .month, .day], from: anchor)
        return CareDay(year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// The full care day: 7 PM the evening before up to 7 PM.
    public func interval(calendar: Calendar = .autoupdatingCurrent) -> DateInterval {
        DateInterval(start: nightStart(calendar), end: at(hour: Self.nightStartHour, calendar))
    }

    /// The night that ended this morning: 7 PM the evening before up to 7 AM.
    public func nightInterval(calendar: Calendar = .autoupdatingCurrent) -> DateInterval {
        DateInterval(start: nightStart(calendar), end: at(hour: Self.morningHour, calendar))
    }

    /// Daytime: 7 AM up to 7 PM.
    public func daytimeInterval(calendar: Calendar = .autoupdatingCurrent) -> DateInterval {
        DateInterval(start: at(hour: Self.morningHour, calendar), end: at(hour: Self.nightStartHour, calendar))
    }

    /// Whether a moment falls in this day's daytime (7 AM up to 7 PM).
    public func isDaytime(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        daytimeInterval(calendar: calendar).includes(date)
    }

    /// Noon on this date, for labels like the weekday.
    public func noon(calendar: Calendar = .autoupdatingCurrent) -> Date {
        at(hour: 12, calendar)
    }

    public func adding(days: Int, calendar: Calendar = .autoupdatingCurrent) -> CareDay {
        let noon = at(hour: 12, calendar)
        return CareDay.containing(calendar.date(byAdding: .day, value: days, to: noon) ?? noon, calendar: calendar)
    }

    /// Whether a moment falls in this care day.
    public func contains(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        interval(calendar: calendar).includes(date)
    }

    public static func < (lhs: CareDay, rhs: CareDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Private

    /// Wall-clock time on this date. Built from components so DST days stay correct.
    private func at(hour: Int, _ calendar: Calendar) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour)
        return calendar.date(from: parts) ?? .distantPast
    }

    private func nightStart(_ calendar: Calendar) -> Date {
        let noon = at(hour: 12, calendar)
        let evening = calendar.date(byAdding: .day, value: -1, to: noon) ?? noon
        return calendar.date(bySettingHour: Self.nightStartHour, minute: 0, second: 0, of: evening) ?? evening
    }
}

extension DateInterval {
    /// Half-open containment: [start, end). `contains(_:)` includes the end.
    func includes(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

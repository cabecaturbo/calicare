import Foundation

/// A night on the accent scale. Lighter is calmer. There is no "bad" level and no red.
public enum CareLevel: Int, Hashable, Sendable, Comparable, CaseIterable {
    case low, medium, high

    public static func < (lhs: CareLevel, rhs: CareLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One day in the 7-day strip. Nil levels mean nothing was logged; that's neutral, never "missed".
public struct WeekDay: Hashable, Sendable, Identifiable {
    public let day: CareDay
    public let nightRating: NightRating?
    public let nightItches: Int
    public let night: CareLevel?
    /// Only the parent's daily answer. Nil means not answered: no data, never
    /// guessed from itches or flares.
    public let skin: SkinToday?
    /// Anything at all was logged that day.
    public let hasLogs: Bool

    public var id: CareDay { day }

    /// Night: the parent's rating if given, otherwise how many itchy wake-ups.
    /// Skin: the day's skinToday answer.
    public init(summary: DaySummary) {
        day = summary.day
        nightRating = summary.nightRating
        nightItches = summary.nightItchEpisodes
        night = Self.nightLevel(rating: summary.nightRating, itches: summary.nightItchEpisodes)
        skin = summary.skinToday
        hasLogs = summary.totalEvents > 0
    }

    static func nightLevel(rating: NightRating?, itches: Int) -> CareLevel? {
        switch rating {
        case .good?: return .low
        case .okay?: return .medium
        case .rough?: return .high
        case nil:
            switch itches {
            case 0: return nil
            case 1: return .low
            case 2...3: return .medium
            default: return .high
            }
        }
    }
}

public enum WeekOverview {
    /// The 7 care days ending with `last`, oldest first, from one batch of logs.
    public static func days(
        ending last: CareDay,
        events: [LogEntry],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [WeekDay] {
        (0..<7).reversed().map { offset in
            let day = last.adding(days: -offset, calendar: calendar)
            return WeekDay(summary: DaySummary(day: day, events: events, calendar: calendar))
        }
    }
}

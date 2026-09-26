import Foundation

/// A point on the sage scale. Lighter is calmer. There is no "bad" level and no red.
public enum CareLevel: Int, Hashable, Sendable, Comparable, CaseIterable {
    case low, medium, high

    public static func < (lhs: CareLevel, rhs: CareLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Plain words for VoiceOver and captions.
    public var skinWords: String {
        switch self {
        case .low: "calm"
        case .medium: "a bit itchy"
        case .high: "itchy"
        }
    }
}

/// One day in the 7-day strip. Nil levels mean nothing was logged; that's neutral, never "missed".
public struct WeekDay: Hashable, Sendable, Identifiable {
    public let day: CareDay
    public let nightRating: NightRating?
    public let nightItches: Int
    public let night: CareLevel?
    public let skin: CareLevel?

    public var id: CareDay { day }
    public var hasLogs: Bool { night != nil || skin != nil }

    /// Night: the parent's rating if given, otherwise how many itchy wake-ups.
    /// Skin: itches through the day, with flares counting more.
    public init(summary: DaySummary) {
        day = summary.day
        nightRating = summary.nightRating
        nightItches = summary.nightItchEpisodes
        night = Self.nightLevel(rating: summary.nightRating, itches: summary.nightItchEpisodes)
        skin = summary.totalEvents == 0
            ? nil
            : Self.skinLevel(itches: summary.itchEpisodes, flares: summary.flares)
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

    /// Each flare counts as three itchy spells.
    static func skinLevel(itches: Int, flares: Int) -> CareLevel {
        switch itches + 3 * flares {
        case ...2: .low
        case 3...5: .medium
        default: .high
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

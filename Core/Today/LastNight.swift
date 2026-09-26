import Foundation

/// The one calm sentence about last night on the Today screen.
public struct LastNightReport: Hashable, Sendable {
    /// The care day whose night this is about.
    public let day: CareDay
    public let rating: NightRating?
    public let itchyWakeUps: Int
    /// True while the night is still going (evening or overnight, with something logged).
    public let isTonight: Bool

    public init(day: CareDay, rating: NightRating?, itchyWakeUps: Int, isTonight: Bool) {
        self.day = day
        self.rating = rating
        self.itchyWakeUps = itchyWakeUps
        self.isTonight = isTonight
    }

    public var hasLogs: Bool { rating != nil || itchyWakeUps > 0 }

    /// "Last night" or "Tonight so far".
    public var heading: String { isTonight ? "Tonight so far" : "Last night" }

    /// E.g. "A rough night, 3 itchy wake-ups." Never judges; just what was logged.
    public var sentence: String {
        let wakeUps = itchyWakeUps == 1 ? "1 itchy wake-up" : "\(itchyWakeUps) itchy wake-ups"
        switch (rating, itchyWakeUps) {
        case (nil, 0):
            return "Nothing logged for last night."
        case (nil, _):
            return isTonight ? "\(wakeUps) so far." : "\(wakeUps) last night."
        case (let rating?, 0):
            return "\(Self.phrase(rating))."
        case (let rating?, _):
            return "\(Self.phrase(rating)), \(wakeUps)."
        }
    }

    /// Picks the night a parent means at `date`. In the daytime that's the night
    /// that ended this morning. In the evening and overnight it's tonight once
    /// something has been logged for it, otherwise last night.
    public static func resolve(
        at date: Date,
        today: DaySummary,
        previous: DaySummary,
        calendar: Calendar = .autoupdatingCurrent
    ) -> LastNightReport {
        let daytime = today.day.daytimeInterval(calendar: calendar).includes(date)
        let tonight = LastNightReport(today, isTonight: !daytime)
        if daytime || tonight.hasLogs { return tonight }
        return LastNightReport(previous, isTonight: false)
    }

    private init(_ summary: DaySummary, isTonight: Bool) {
        self.init(
            day: summary.day,
            rating: summary.nightRating,
            itchyWakeUps: summary.nightItchEpisodes,
            isTonight: isTonight
        )
    }

    private static func phrase(_ rating: NightRating) -> String {
        switch rating {
        case .good: "A good night"
        case .okay: "An okay night"
        case .rough: "A rough night"
        }
    }
}

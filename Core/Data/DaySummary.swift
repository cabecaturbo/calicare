import Foundation

/// Counts and latest values for one care day. Built from logs, no judgement attached.
public struct DaySummary: Hashable, Sendable {
    public let day: CareDay
    public let nightRating: NightRating?
    public let nightItchEpisodes: Int
    public let daytimeItchEpisodes: Int
    public let flares: Int
    /// Kinds that were given, in order. Logs without a kind aren't listed here.
    public let bowelMovements: [BowelMovement]
    /// Bowel movements that happened, with or without a kind (an explicit "none" isn't one).
    public let bowelMovementCount: Int
    public let mood: Mood?
    public let routinesDone: Int
    public let notes: Int
    public let totalEvents: Int

    public var itchEpisodes: Int { nightItchEpisodes + daytimeItchEpisodes }

    /// Summarizes `events`, ignoring any that fall outside `day`.
    public init(day: CareDay, events: [LogEntry], calendar: Calendar = .autoupdatingCurrent) {
        let night = day.nightInterval(calendar: calendar)
        let inDay = events
            .filter { day.contains($0.timestamp, calendar: calendar) }
            .sorted { $0.timestamp < $1.timestamp }
        let itches = inDay.filter { $0.type == .itchEpisode }

        self.day = day
        self.nightRating = inDay.compactMap { entry -> NightRating? in
            if case .night(let rating)? = entry.value { return rating }
            return nil
        }.last
        self.nightItchEpisodes = itches.filter { night.includes($0.timestamp) }.count
        self.daytimeItchEpisodes = itches.count - nightItchEpisodes
        self.flares = inDay.filter { $0.type == .flare }.count
        self.bowelMovements = inDay.compactMap { entry -> BowelMovement? in
            if case .bowel(let movement)? = entry.value { return movement }
            return nil
        }
        self.bowelMovementCount = inDay.filter {
            $0.type == .bowelMovement && $0.value != .bowel(BowelMovement.none)
        }.count
        self.mood = inDay.compactMap { entry -> Mood? in
            if case .mood(let mood)? = entry.value { return mood }
            return nil
        }.last
        self.routinesDone = inDay.filter { $0.type == .routineDone }.count
        self.notes = inDay.filter { $0.type == .note }.count
        self.totalEvents = inDay.count
    }
}

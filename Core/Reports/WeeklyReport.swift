import Foundation

/// How one child's week went, from their logs. Pure: no UI, no storage.
/// Days with nothing logged are left out of every count and comparison;
/// they're never shown as failures.
public struct WeeklyReport: Equatable, Sendable {
    public let child: ChildInfo
    /// The last care day in the week (7 PM the evening before to 7 PM).
    public let weekEnding: CareDay
    /// The 7 days, oldest first, with the same night and skin levels as the Today strip.
    public let days: [WeekDay]
    /// Days with at least one log. Everything below counts these only.
    public let daysWithLogs: Int

    public let goodNights: Int
    /// Nights with a rating (good, okay, or rough).
    public let ratedNights: Int
    public let roughNights: Int
    public let itchyWakeUps: Int
    /// Nil when last week had too few logs to compare with.
    public let itchyWakeUpsLastWeek: Int?
    public let flares: Int
    public let routinesDone: Int
    /// Logged days with at least one routine done.
    public let routineDays: Int
    public let bowelMovements: Int
    /// The mood logged most often, if any. Ties go to the calmer one.
    public let usualMood: Mood?
    public let moodsLogged: Int
    /// Filled in by Phase 5 (food). Always empty for now.
    public let newSafeFoods: [String]

    public let headline: Headline
    /// One line, only when something clearly changed. Notices; never explains.
    public let worthWatching: String?

    /// Below this many logged days, there's no summary.
    public static let minimumDays = 3

    public enum Headline: Equatable, Sendable {
        case calmer, harder, aboutTheSame, firstWeek, notEnoughLogs

        public var text: String {
            switch self {
            case .calmer: "A calmer week"
            case .harder: "A harder week"
            case .aboutTheSame: "About the same as last week"
            case .firstWeek: "A first week of logs"
            case .notEnoughLogs: "Not enough logs yet for a summary"
            }
        }
    }
}

extension WeeklyReport {
    /// Builds the report for `child` from logs covering this week and last
    /// (14 care days ending `weekEnding`). Logs for other children are ignored.
    public init(
        child: ChildInfo,
        weekEnding: CareDay,
        events: [LogEntry],
        calendar: Calendar = .autoupdatingCurrent
    ) {
        let mine = events.filter { $0.childID == child.id }
        let this = Week(ending: weekEnding, events: mine, calendar: calendar)
        let last = Week(ending: weekEnding.adding(days: -7, calendar: calendar), events: mine, calendar: calendar)
        let comparable = last.logged.count >= Self.minimumDays

        self.child = child
        self.weekEnding = weekEnding
        days = this.days
        daysWithLogs = this.logged.count
        goodNights = this.logged.filter { $0.nightRating == .good }.count
        ratedNights = this.logged.filter { $0.nightRating != nil }.count
        roughNights = this.roughNights
        itchyWakeUps = this.itchyWakeUps
        itchyWakeUpsLastWeek = comparable ? last.itchyWakeUps : nil
        flares = this.flares
        routinesDone = this.logged.reduce(0) { $0 + $1.routinesDone }
        routineDays = this.logged.filter { $0.routinesDone > 0 }.count
        bowelMovements = this.logged.reduce(0) { $0 + $1.bowelMovementCount }
        let moods = this.logged.compactMap(\.mood)
        moodsLogged = moods.count
        usualMood = Self.usual(moods)
        newSafeFoods = []

        if this.logged.count < Self.minimumDays {
            headline = .notEnoughLogs
            worthWatching = nil
        } else if !comparable {
            headline = .firstWeek
            worthWatching = nil
        } else {
            let line = Self.worthWatching(this, last)
            let compared = Self.compare(this, with: last)
            // Never "a calmer week" above a line saying something got worse.
            headline = compared == .calmer && line != nil ? .aboutTheSame : compared
            worthWatching = line
        }
    }

    /// The mood logged most often. On a tie, the calmer one (listed first) wins.
    static func usual(_ moods: [Mood]) -> Mood? {
        var best: (mood: Mood, count: Int)?
        for mood in Mood.allCases {
            let count = moods.filter { $0 == mood }.count
            if count > 0, count > (best?.count ?? 0) { best = (mood, count) }
        }
        return best?.mood
    }

    /// Calmer or harder by the average night level and skin answer on logged days.
    /// Skin counts only when both weeks have answers.
    /// Half a level of change either way counts; anything smaller is "about the same".
    static func compare(_ this: Week, with last: Week) -> Headline {
        var change = 0.0
        if let now = this.averageNight, let before = last.averageNight { change += now - before }
        if let now = this.averageSkin, let before = last.averageSkin { change += now - before }
        if change <= -0.5 { return .calmer }
        if change >= 0.5 { return .harder }
        return .aboutTheSame
    }

    /// The first clear change, in plain words. Nil when nothing clearly changed.
    static func worthWatching(_ this: Week, _ last: Week) -> String? {
        if this.itchyWakeUps - last.itchyWakeUps >= 3 { return "Itchy wake-ups went up this week." }
        if this.roughNights - last.roughNights >= 2 { return "More rough nights this week." }
        if this.flares - last.flares >= 2 { return "More flares this week." }
        return nil
    }
}

/// One week's days and the numbers the report compares.
struct Week {
    let days: [WeekDay]
    let logged: [DaySummary]

    init(ending: CareDay, events: [LogEntry], calendar: Calendar) {
        self.init(days: (0..<7).reversed().map { ending.adding(days: -$0, calendar: calendar) }, events: events, calendar: calendar)
    }

    /// Any run of days (the monthly report uses a calendar month).
    init(days careDays: [CareDay], events: [LogEntry], calendar: Calendar) {
        let summaries = careDays.map { DaySummary(day: $0, events: events, calendar: calendar) }
        days = summaries.map(WeekDay.init(summary:))
        logged = summaries.filter { $0.totalEvents > 0 }
    }

    var itchyWakeUps: Int { logged.reduce(0) { $0 + $1.nightItchEpisodes } }
    var roughNights: Int { logged.filter { $0.nightRating == .rough }.count }
    var flares: Int { logged.reduce(0) { $0 + $1.flares } }
    var averageNight: Double? { Self.average(days.compactMap(\.night)) }
    /// Skin answers on the night levels' 0…2 scale: indigo step 1 is 0, step 5 is 2.
    var averageSkin: Double? {
        Self.average(days.compactMap(\.skin).map { Double($0.step - 1) / 2 })
    }

    static func average(_ levels: [CareLevel]) -> Double? {
        average(levels.map { Double($0.rawValue) })
    }

    static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

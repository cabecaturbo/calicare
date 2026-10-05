import Foundation

/// The Night strip widget: recent nights as rows of dots, one dot per itch
/// (wake-up), placed along 7 PM to 7 AM. A night belongs to the morning it
/// ends, like everywhere else. Built from logs, no judgement attached.
public struct NightStrip: Equatable, Sendable {
    public struct Night: Equatable, Sendable, Identifiable {
        /// The care day whose night this is: the morning it ends.
        public let day: CareDay
        /// Wake-up times, oldest first.
        public let wakeUps: [Date]
        /// Where each wake-up sits along the night, 0 (7 PM) to 1 (7 AM).
        public let positions: [Double]
        /// That day's skin answer, for the row's light tint. Nil when not answered.
        public let skin: SkinToday?
        /// True for tonight, while it's still going.
        public let isTonight: Bool

        public var id: CareDay { day }
        public var count: Int { wakeUps.count }
    }

    /// Oldest first; the last row is last night (by day) or tonight (from 7 PM).
    public let nights: [Night]

    /// No wake-ups logged on any of these nights.
    public var isEmpty: Bool { nights.allSatisfy { $0.wakeUps.isEmpty } }

    /// The last `count` nights up to the care day containing `now`.
    /// `events` may hold anything; only itches inside each night are drawn.
    public init(events: [LogEntry], count: Int, now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let last = CareDay.containing(now, calendar: calendar)
        let tonight = !last.isDaytime(now, calendar: calendar)
            && last.nightInterval(calendar: calendar).includes(now)
        let itches = events.filter { $0.type == .itchEpisode }.sorted { $0.timestamp < $1.timestamp }
        self.nights = (0..<max(count, 0)).reversed().map { back in
            let day = last.adding(days: -back, calendar: calendar)
            let night = day.nightInterval(calendar: calendar)
            let times = itches.map(\.timestamp).filter { night.includes($0) }
            return Night(
                day: day,
                wakeUps: times,
                positions: times.map { Self.position(of: $0, in: night) },
                skin: DaySummary(day: day, events: events, calendar: calendar).skinToday,
                isTonight: back == 0 && tonight
            )
        }
    }

    /// The share of the night that had passed at `date`, from 0 at 7 PM to 1 at
    /// 7 AM. Real elapsed time, so the short and long nights around daylight
    /// saving still run edge to edge.
    public static func position(of date: Date, in night: DateInterval) -> Double {
        guard night.duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(night.start) / night.duration, 0), 1)
    }

    /// "Last 7 nights. Monday, 3 wake-ups. Tuesday, no wake-ups logged. Tonight so far, 1 wake-up."
    public func accessibilitySummary(calendar: Calendar = .autoupdatingCurrent) -> String {
        guard !isEmpty else { return Self.emptyText }
        let weekday = DateFormatter()
        weekday.calendar = calendar
        weekday.timeZone = calendar.timeZone
        weekday.dateFormat = "EEEE"
        let rows = nights.map { night -> String in
            let name = night.isTonight ? "Tonight so far" : weekday.string(from: night.day.noon(calendar: calendar))
            return "\(name), \(Self.wakeUps(night.count))."
        }
        return (["Last \(nights.count) nights."] + rows).joined(separator: " ")
    }

    /// "Mon", the morning a night ends.
    public static func shortWeekday(_ day: CareDay, calendar: Calendar = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.noon(calendar: calendar))
    }

    public static let emptyText = "Tap Log tonight, and your nights will show up here."

    static func wakeUps(_ count: Int) -> String {
        switch count {
        case 0: "no wake-ups logged"
        case 1: "1 wake-up"
        default: "\(count) wake-ups"
        }
    }
}

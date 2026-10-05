import Foundation

/// One night for "Tonight": its 7 PM–7 AM window (counted toward the morning
/// it ends, like everywhere else) and the wake-ups logged in it. Pure, so the
/// Lock Screen card, the morning summary, and the share text are all tested.
public struct TonightNight: Equatable, Sendable {
    /// The morning this night counts toward.
    public let day: CareDay
    public let start: Date
    public let end: Date
    /// Itch logs inside the window, oldest first.
    public let wakeUps: [Date]

    public init(day: CareDay, events: [LogEntry], calendar: Calendar = .autoupdatingCurrent) {
        let window = day.nightInterval(calendar: calendar)
        self.day = day
        self.start = window.start
        self.end = window.end
        self.wakeUps = events
            .filter { $0.type == .itchEpisode && $0.timestamp >= window.start && $0.timestamp < window.end }
            .map(\.timestamp)
            .sorted()
    }

    /// The night "Tonight" means at `date`: the one in progress (7 PM–7 AM),
    /// or during the day, the one coming up this evening.
    public static func day(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> CareDay {
        let day = CareDay.containing(date, calendar: calendar)
        return day.isDaytime(date, calendar: calendar) ? day.adding(days: 1, calendar: calendar) : day
    }

    /// The most recent night that has started: the one in progress at night,
    /// or during the day, the one that ended at 7 AM.
    public static func lastNight(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> CareDay {
        CareDay.containing(date, calendar: calendar)
    }

    public var count: Int { wakeUps.count }
    public var last: Date? { wakeUps.last }
    /// The words for this night's wake-ups.
    public var words: NightWords { NightWords(wakeUps: wakeUps) }
}

/// What a night's wake-ups say, from the times alone (the Lock Screen card
/// uses this without opening the store).
public struct NightWords: Equatable, Sendable {
    public let wakeUps: [Date]

    public init(wakeUps: [Date]) {
        self.wakeUps = wakeUps.sorted()
    }

    public var count: Int { wakeUps.count }
    public var last: Date? { wakeUps.last }
    /// "No wake-ups yet." / "1 wake-up · last at 1:52 AM" / "2 wake-ups · last at 1:52 AM"
    public func line(time: (Date) -> String) -> String {
        guard let last else { return "No wake-ups yet." }
        return "\(Self.wakeUps(count)) · last at \(time(last))"
    }

    /// VoiceOver: "2 wake-ups tonight, last at 1:52 AM." / "No wake-ups tonight yet."
    public func spokenLine(time: (Date) -> String) -> String {
        guard let last else { return "No wake-ups tonight yet." }
        return "\(Self.wakeUps(count)) tonight, last at \(time(last))."
    }

    /// The morning card: "Last night: 3 wake-ups (11:40, 1:52, 4:10)." Times
    /// without AM/PM to stay short; the share text spells them out.
    public func summary(shortTime: (Date) -> String) -> String {
        guard !wakeUps.isEmpty else { return "Last night: no wake-ups logged." }
        let times = wakeUps.map(shortTime).joined(separator: ", ")
        return "Last night: \(Self.wakeUps(count)) (\(times))."
    }

    /// Plain text to send: "Last night: 3 wake-ups, at 11:40 PM, 1:52 AM, and 4:10 AM."
    public func shareText(time: (Date) -> String) -> String {
        let times = wakeUps.map(time)
        switch times.count {
        case 0: return "Last night: no wake-ups logged."
        case 1: return "Last night: 1 wake-up, at \(times[0])."
        case 2: return "Last night: 2 wake-ups, at \(times[0]) and \(times[1])."
        default:
            return "Last night: \(times.count) wake-ups, at " + times.dropLast().joined(separator: ", ") + ", and \(times.last!)."
        }
    }

    static func wakeUps(_ count: Int) -> String {
        count == 1 ? "1 wake-up" : "\(count) wake-ups"
    }
}

/// Clock formats for Tonight: "1:52 AM" and "1:52".
public enum TonightClock {
    public static func time(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        formatter("h:mm a", calendar).string(from: date)
    }

    public static func shortTime(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        formatter("h:mm", calendar).string(from: date)
    }

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        return f
    }
}

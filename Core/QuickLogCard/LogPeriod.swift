import Foundation

/// The stretch of time the Quick Log card counts: the day (7 AM–7 PM) or the
/// night (7 PM–7 AM, counted toward the morning it ends, like everywhere
/// else), and the itch logs in it. Pure, so the card's words, the summary,
/// and the share text are all tested.
public struct LogPeriod: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case day, night }

    public let kind: Kind
    /// The care day this belongs to (a night belongs to the morning it ends).
    public let day: CareDay
    public let start: Date
    public let end: Date
    /// Itch logs inside the window, oldest first.
    public let itches: [Date]

    public init(kind: Kind, day: CareDay, events: [LogEntry], calendar: Calendar = .autoupdatingCurrent) {
        let window = kind == .night ? day.nightInterval(calendar: calendar) : day.daytimeInterval(calendar: calendar)
        self.kind = kind
        self.day = day
        self.start = window.start
        self.end = window.end
        self.itches = events
            .filter { $0.type == .itchEpisode && $0.timestamp >= window.start && $0.timestamp < window.end }
            .map(\.timestamp)
            .sorted()
    }

    /// Which period `date` falls in: 7 AM–7 PM is the day, the rest is the night.
    public static func current(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> (kind: Kind, day: CareDay) {
        let day = CareDay.containing(date, calendar: calendar)
        return day.isDaytime(date, calendar: calendar) ? (.day, day) : (.night, day)
    }

    /// The most recent night that has started: the one in progress at night,
    /// or during the day, the one that ended at 7 AM.
    public static func lastNight(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> CareDay {
        CareDay.containing(date, calendar: calendar)
    }

    public var words: PeriodWords { PeriodWords(kind: kind, itches: itches) }
}

/// What a period's itch logs say, from the times alone (the Lock Screen card
/// uses this without opening the store). At night an itch log is a wake-up.
public struct PeriodWords: Equatable, Sendable {
    public let kind: LogPeriod.Kind
    public let itches: [Date]

    public init(kind: LogPeriod.Kind, itches: [Date]) {
        self.kind = kind
        self.itches = itches.sorted()
    }

    public var count: Int { itches.count }
    public var last: Date? { itches.last }

    /// "Tonight" or "Today".
    public var heading: String { kind == .night ? "Tonight" : "Today" }

    /// "2 wake-ups" / "1 itch"
    public var amount: String {
        switch kind {
        case .night: count == 1 ? "1 wake-up" : "\(count) wake-ups"
        case .day: count == 1 ? "1 itch" : "\(count) itches"
        }
    }

    /// Card line: "Tonight: no wake-ups yet." / "Tonight: 2 wake-ups · last at 1:52 AM"
    /// / "Today: nothing logged yet." / "Today: 1 itch · last at 3:10 PM"
    public func line(time: (Date) -> String) -> String {
        guard let last else {
            return kind == .night ? "Tonight: no wake-ups yet." : "Today: nothing logged yet."
        }
        return "\(heading): \(amount) · last at \(time(last))"
    }

    /// VoiceOver: "2 wake-ups tonight, last at 1:52 AM." / "No itching logged today yet."
    public func spokenLine(time: (Date) -> String) -> String {
        let when = kind == .night ? "tonight" : "today"
        guard let last else {
            return kind == .night ? "No wake-ups tonight yet." : "No itching logged today yet."
        }
        return "\(amount) \(when), last at \(time(last))."
    }

    /// When the period is over: "Last night: 3 wake-ups (11:40, 1:52, 4:10)."
    /// or "Today: 2 itches (9:10, 3:40)." Times without AM/PM to stay short.
    public func summary(shortTime: (Date) -> String) -> String {
        let label = kind == .night ? "Last night" : "Today"
        guard !itches.isEmpty else {
            return kind == .night ? "Last night: no wake-ups logged." : "Today: no itching logged."
        }
        return "\(label): \(amount) (" + itches.map(shortTime).joined(separator: ", ") + ")."
    }

    /// Plain text to send: "Last night: 3 wake-ups, at 11:40 PM, 1:52 AM, and 4:10 AM."
    public func shareText(time: (Date) -> String) -> String {
        let label = kind == .night ? "Last night" : "Today"
        let times = itches.map(time)
        switch times.count {
        case 0: return kind == .night ? "Last night: no wake-ups logged." : "Today: no itching logged."
        case 1: return "\(label): \(amount), at \(times[0])."
        case 2: return "\(label): \(amount), at \(times[0]) and \(times[1])."
        default:
            return "\(label): \(amount), at " + times.dropLast().joined(separator: ", ") + ", and \(times.last!)."
        }
    }
}

/// Clock formats for the card: "1:52 AM" and "1:52".
public enum CardClock {
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

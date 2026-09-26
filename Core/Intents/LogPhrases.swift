import Foundation

/// Short, warm words for what was logged, used by Siri, Shortcuts, and undo.
public struct LogPhrases: Sendable {
    public static let nothingToUndo = "Nothing to undo from the last 10 minutes. All good."

    private let calendar: Calendar
    private let locale: Locale

    public init(calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        self.calendar = calendar
        self.locale = locale
    }

    /// "Logged itchy wake-up for Cal, 2:14 AM."
    public func logged(_ entry: LogEntry, childName: String) -> String {
        "Logged \(name(for: entry)) for \(childName), \(time(entry.timestamp))."
    }

    /// "Removed itchy wake-up, 2:14 AM."
    public func removed(_ entry: LogEntry) -> String {
        "Removed \(name(for: entry)), \(time(entry.timestamp))."
    }

    /// What a log is called in a sentence, e.g. "rough night" or "itchy wake-up".
    public func name(for entry: LogEntry) -> String {
        switch (entry.type, entry.value) {
        case (.nightRating, .night(let rating)?): "\(rating.rawValue) night"
        case (.nightRating, _): "night"
        case (.itchEpisode, _): isNight(entry.timestamp) ? "itchy wake-up" : "itchy spell"
        case (.flare, _): "flare"
        case (.bowelMovement, .bowel(BowelMovement.none)?): "no bowel movement"
        case (.bowelMovement, .bowel(let movement)?): "\(movement.rawValue) bowel movement"
        case (.bowelMovement, _): "bowel movement"
        case (.mood, .mood(let mood)?): "\(mood.rawValue) mood"
        case (.mood, _): "mood"
        case (.routineDone, _): "routine"
        case (.note, _): "note"
        }
    }

    /// "2:14 AM", with a plain space so it reads and speaks cleanly.
    public func time(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.locale = locale
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    /// Same night window the day summary uses: 7 PM to 7 AM.
    private func isNight(_ date: Date) -> Bool {
        CareDay.containing(date, calendar: calendar)
            .nightInterval(calendar: calendar)
            .includes(date)
    }
}

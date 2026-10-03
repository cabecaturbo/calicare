import Foundation

/// When Today asks things. Pure rules, so they're easy to test.
public enum TodayPrompts {
    /// The skin question waits until the day has mostly happened.
    public static let skinQuestionHour = 16

    /// Whether Today asks "How was the skin today?" at `date`: from 4 PM until
    /// night mode, and only while the day's skin isn't answered.
    public static func asksSkin(at date: Date, answered: Bool, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard !answered, !NightMode.isActive(at: date, calendar: calendar) else { return false }
        return calendar.component(.hour, from: date) >= skinQuestionHour
    }

    /// The one line under the header until the first log for any child.
    public static func firstRunHint(hasEverLogged: Bool, isNight: Bool, asksSkin: Bool, childName: String) -> String? {
        guard !hasEverLogged else { return nil }
        if isNight { return "Tap Log whenever \(childName) wakes up itchy." }
        return asksSkin ? "Start here: one tap for today’s skin." : "Start here: tap Log whenever \(childName) scratches."
    }
}

import Foundation

/// Which day a "How was the skin today?" answer is about.
///
/// Care days run 7 PM to 7 PM, so an answer given at 8 PM would land on
/// tomorrow. Skin is about the daytime, so an answer given at night
/// (7 PM – 7 AM) counts for the day that just ended, filed at 6:59 PM.
public enum SkinDay {
    public static func timestamp(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let day = CareDay.containing(date, calendar: calendar)
        if day.isDaytime(date, calendar: calendar) { return date }
        let endedDay = day.adding(days: -1, calendar: calendar)
        return endedDay.interval(calendar: calendar).end.addingTimeInterval(-60)
    }

    /// The care day an answer given at `date` is about.
    public static func day(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> CareDay {
        CareDay.containing(timestamp(for: date, calendar: calendar), calendar: calendar)
    }
}

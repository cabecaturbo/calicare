import Foundation

/// When widgets need a fresh entry.
public enum WidgetTimeline {
    /// Now, when "Logged" should go away, and the next 7 AM (morning, night
    /// palette off) and 7 PM (new care day, night palette on).
    public static func dates(
        from now: Date,
        feedback: WidgetFeedback?,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date] {
        var dates: Set<Date> = [now]
        if let feedback, feedback.isShowing(at: now) {
            dates.insert(feedback.expiresAt)
        }
        let hours = Set([CareDay.morningHour, CareDay.nightStartHour, NightMode.startHour, NightMode.endHour])
        for hour in hours {
            let next = calendar.nextDate(
                after: now,
                matching: DateComponents(hour: hour, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )
            if let next { dates.insert(next) }
        }
        return dates.sorted()
    }
}

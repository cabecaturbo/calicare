import Foundation

/// What a widget shows for one child at one moment.
public struct WidgetSnapshot: Hashable, Sendable {
    /// Nil when no child has been added yet.
    public let child: ChildInfo?
    public let itchCount: Int
    public let bowelMovementCount: Int
    public let routinesDone: Int
    public let lastNight: NightRating?
    public let lastItch: Date?
    /// "by Dad" when more than one person shares the household.
    public let lastItchBy: String?
    /// Itchy wake-ups in the night being shown: last night by day, tonight from 7 PM.
    public let nightWakeUps: Int
    /// True from 7 PM to 7 AM, when the widget talks about tonight.
    public let isNight: Bool

    public init(
        child: ChildInfo?,
        itchCount: Int = 0,
        bowelMovementCount: Int = 0,
        routinesDone: Int = 0,
        lastNight: NightRating? = nil,
        lastItch: Date? = nil,
        lastItchBy: String? = nil,
        nightWakeUps: Int = 0,
        isNight: Bool = false
    ) {
        self.child = child
        self.itchCount = itchCount
        self.bowelMovementCount = bowelMovementCount
        self.routinesDone = routinesDone
        self.lastNight = lastNight
        self.lastItch = lastItch
        self.lastItchBy = lastItchBy
        self.nightWakeUps = nightWakeUps
        self.isNight = isNight
    }

    /// Nothing to show yet: no child.
    public static let empty = WidgetSnapshot(child: nil)

    /// For the widget gallery and placeholders.
    public static let sample = WidgetSnapshot(
        child: ChildInfo(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000CA11") ?? UUID(),
            name: "Cal",
            birthDate: nil,
            colorTag: "sage",
            isActive: true
        ),
        itchCount: 2,
        bowelMovementCount: 1,
        routinesDone: 1,
        lastNight: .okay,
        lastItch: nil,
        nightWakeUps: 2
    )

    /// The night a parent means by "last night" at `date`.
    /// In the daytime that's the night that ended this morning. In the evening
    /// and overnight it's tonight's rating if there is one, else last night's.
    static func resolveLastNight(
        at date: Date,
        today: DaySummary,
        previous: DaySummary,
        calendar: Calendar
    ) -> NightRating? {
        if today.day.daytimeInterval(calendar: calendar).includes(date) {
            return today.nightRating
        }
        return today.nightRating ?? previous.nightRating
    }
}

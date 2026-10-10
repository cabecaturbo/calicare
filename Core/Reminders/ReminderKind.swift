import Foundation

/// The reminders a parent can turn on, in the order Settings lists them.
public enum ReminderKind: String, Codable, Sendable, CaseIterable {
    // Raw values stay as saved; the list reminders were the routine reminders.
    case checkIn, skinCheckIn, morningRoutine, afternoonRoutine, eveningRoutine
    /// "Show the Log card for tonight?": opens the app to add the card.
    case tonight

    /// Which routine this reminds about; nil for the check-ins and afternoon.
    public var routineTime: RoutineTime? {
        switch self {
        case .checkIn, .skinCheckIn, .afternoonRoutine, .tonight: nil
        case .morningRoutine: .morning
        case .eveningRoutine: .evening
        }
    }

    /// Which To do block this reminds about; nil for the check-ins.
    public var todoBlock: TodoBlock? {
        switch self {
        case .checkIn, .skinCheckIn, .tonight: nil
        case .morningRoutine: .morning
        case .afternoonRoutine: .afternoon
        case .eveningRoutine: .bedtime
        }
    }

    var categoryID: String {
        switch self {
        case .checkIn: ReminderIDs.checkInCategory
        case .skinCheckIn: ReminderIDs.skinCategory
        case .morningRoutine, .afternoonRoutine, .eveningRoutine: ReminderIDs.routineCategory
        case .tonight: ReminderIDs.tonightCategory
        }
    }

    /// One-off reminders planned per care day and skipped once that day is answered.
    var isDailyQuestion: Bool { self == .checkIn || self == .skinCheckIn }

    var threadID: String { "calicare.thread.\(rawValue)" }
}

/// The buttons on reminder notifications.
public enum ReminderAction: String, Sendable, CaseIterable {
    case good, okay, rough, done, snooze
    case calm, littleItchy, flaring, veryRough

    public var identifier: String { "calicare.action.\(rawValue)" }

    public init?(identifier: String) {
        guard let match = Self.allCases.first(where: { $0.identifier == identifier }) else { return nil }
        self = match
    }

    public var title: String {
        switch self {
        case .good: "Good"
        case .okay: "Okay"
        case .rough: "Rough"
        case .done: "All done"
        case .snooze: "Snooze 30 min"
        case .calm, .littleItchy, .flaring, .veryRough: skinToday?.title ?? ""
        }
    }

    var nightRating: NightRating? {
        switch self {
        case .good: .good
        case .okay: .okay
        case .rough: .rough
        default: nil
        }
    }

    var skinToday: SkinToday? {
        switch self {
        case .calm: .calm
        case .littleItchy: .littleItchy
        case .flaring: .flaring
        case .veryRough: .veryRough
        default: nil
        }
    }
}

/// Notification request and category identifiers.
enum ReminderIDs {
    static let checkInCategory = "calicare.category.checkIn"
    static let routineCategory = "calicare.category.routine"
    static let skinCategory = "calicare.category.skin"
    static let tonightCategory = "calicare.category.tonight"

    private static let checkInPrefix = "calicare.checkIn."
    private static let skinPrefix = "calicare.skin."
    private static let snoozePrefix = "calicare.snooze."

    static func checkIn(for day: CareDay) -> String { checkInPrefix + day.description }
    static func skinCheckIn(for day: CareDay) -> String { skinPrefix + day.description }

    /// The one-off request for a daily question on one care day.
    static func question(_ kind: ReminderKind, for day: CareDay) -> String {
        kind == .skinCheckIn ? skinCheckIn(for: day) : checkIn(for: day)
    }
    static func routine(_ kind: ReminderKind) -> String { "calicare.\(kind.rawValue)" }
    static func snooze(_ kind: ReminderKind) -> String { snoozePrefix + kind.rawValue }
    static func test(_ kind: ReminderKind) -> String { "calicare.test.\(kind.rawValue)" }

    /// Requests a refresh owns and may replace: check-ins and repeating routines.
    /// Snoozes and test notifications are left alone.
    static func isPlanned(_ id: String) -> Bool {
        id.hasPrefix(checkInPrefix) || id.hasPrefix(skinPrefix)
            || id == routine(.morningRoutine) || id == routine(.afternoonRoutine) || id == routine(.eveningRoutine)
            || id == routine(.tonight)
    }

    /// The reminder a snooze request belongs to.
    static func snoozedKind(_ id: String) -> ReminderKind? {
        guard id.hasPrefix(snoozePrefix) else { return nil }
        return ReminderKind(rawValue: String(id.dropFirst(snoozePrefix.count)))
    }
}

import Foundation

/// The three reminders a parent can turn on.
public enum ReminderKind: String, Codable, Sendable, CaseIterable {
    case checkIn, morningRoutine, eveningRoutine

    /// Which routine this reminds about; nil for the morning check-in.
    public var routineTime: RoutineTime? {
        switch self {
        case .checkIn: nil
        case .morningRoutine: .morning
        case .eveningRoutine: .evening
        }
    }

    var categoryID: String {
        self == .checkIn ? ReminderIDs.checkInCategory : ReminderIDs.routineCategory
    }

    var threadID: String { "calicare.thread.\(rawValue)" }
}

/// The buttons on reminder notifications.
public enum ReminderAction: String, Sendable, CaseIterable {
    case good, okay, rough, done, snooze

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
        case .done: "Done"
        case .snooze: "Snooze 30 min"
        }
    }

    var nightRating: NightRating? {
        switch self {
        case .good: .good
        case .okay: .okay
        case .rough: .rough
        case .done, .snooze: nil
        }
    }
}

/// Notification request and category identifiers.
enum ReminderIDs {
    static let checkInCategory = "calicare.category.checkIn"
    static let routineCategory = "calicare.category.routine"

    private static let checkInPrefix = "calicare.checkIn."
    private static let snoozePrefix = "calicare.snooze."

    static func checkIn(for day: CareDay) -> String { checkInPrefix + day.description }
    static func routine(_ kind: ReminderKind) -> String { "calicare.\(kind.rawValue)" }
    static func snooze(_ kind: ReminderKind) -> String { snoozePrefix + kind.rawValue }
    static func test(_ kind: ReminderKind) -> String { "calicare.test.\(kind.rawValue)" }

    /// Requests a refresh owns and may replace: check-ins and repeating routines.
    /// Snoozes and test notifications are left alone.
    static func isPlanned(_ id: String) -> Bool {
        id.hasPrefix(checkInPrefix) || id == routine(.morningRoutine) || id == routine(.eveningRoutine)
    }

    /// The reminder a snooze request belongs to.
    static func snoozedKind(_ id: String) -> ReminderKind? {
        guard id.hasPrefix(snoozePrefix) else { return nil }
        return ReminderKind(rawValue: String(id.dropFirst(snoozePrefix.count)))
    }
}

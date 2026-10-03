import Foundation

/// What a notification carries so its buttons know what to log.
public struct ReminderPayload: Hashable, Sendable {
    public let kind: ReminderKind
    public let childID: UUID?
    /// When a one-off reminder was due. Nil for repeating routines.
    public let fireDate: Date?

    public init(kind: ReminderKind, childID: UUID?, fireDate: Date?) {
        self.kind = kind
        self.childID = childID
        self.fireDate = fireDate
    }

    /// Plain strings, safe for notification userInfo.
    public var userInfo: [String: String] {
        var info = ["kind": kind.rawValue]
        info["childID"] = childID?.uuidString
        info["fireDate"] = fireDate.map { String($0.timeIntervalSince1970) }
        return info
    }

    /// Reads a notification's userInfo. Nil if it isn't one of ours.
    public init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo["kind"] as? String, let kind = ReminderKind(rawValue: raw) else { return nil }
        self.kind = kind
        self.childID = (userInfo["childID"] as? String).flatMap(UUID.init(uuidString:))
        self.fireDate = (userInfo["fireDate"] as? String)
            .flatMap(TimeInterval.init)
            .map(Date.init(timeIntervalSince1970:))
    }
}

/// A notification to schedule, independent of UserNotifications so it can be tested.
public struct PlannedReminder: Hashable, Sendable {
    public enum Trigger: Hashable, Sendable {
        /// Once, at this wall-clock date and time.
        case once(DateComponents)
        /// Every day at this time.
        case daily(hour: Int, minute: Int)
        /// Once, this many seconds from when it's scheduled.
        case after(TimeInterval)
    }

    public let id: String
    public let trigger: Trigger
    public let title: String
    public let body: String
    public let payload: ReminderPayload

    public var kind: ReminderKind { payload.kind }
}

/// Works out which reminders should be pending. Pure: no notifications, no database.
public struct ReminderPlanner: Sendable {
    /// Check-ins are scheduled one day at a time so a logged night can skip its morning.
    public static let checkInDays = 14
    public static let snoozeInterval: TimeInterval = 30 * 60

    private let calendar: Calendar

    public init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    /// Every reminder that should be pending for `child`.
    /// Skips the morning check-in on any care day in `ratedDays` (a night rating is
    /// already logged), and the skin check-in on any day in `skinDays` (already answered).
    public func plan(
        settings: ReminderSettings,
        child: ChildInfo?,
        ratedDays: Set<CareDay>,
        skinDays: Set<CareDay> = [],
        now: Date
    ) -> [PlannedReminder] {
        guard let child else { return [] }
        var reminders: [PlannedReminder] = []
        if settings.checkIn.isOn {
            reminders += questions(.checkIn, at: settings.checkIn, child: child, answered: ratedDays, now: now)
        }
        if settings.skinCheckIn.isOn {
            reminders += questions(.skinCheckIn, at: settings.skinCheckIn, child: child, answered: skinDays, now: now)
        }
        for kind in [ReminderKind.morningRoutine, .eveningRoutine] where settings[kind].isOn {
            let slot = settings[kind]
            reminders.append(PlannedReminder(
                id: ReminderIDs.routine(kind),
                trigger: .daily(hour: slot.hour, minute: slot.minute),
                title: ReminderCopy.title(kind, childName: child.name),
                body: ReminderCopy.body(kind),
                payload: ReminderPayload(kind: kind, childID: child.id, fireDate: nil)
            ))
        }
        return reminders
    }

    /// The same reminder again, 30 minutes from now.
    public func snooze(_ payload: ReminderPayload, childName: String) -> PlannedReminder {
        PlannedReminder(
            id: ReminderIDs.snooze(payload.kind),
            trigger: .after(Self.snoozeInterval),
            title: ReminderCopy.title(payload.kind, childName: childName),
            body: ReminderCopy.body(payload.kind),
            payload: payload
        )
    }

    /// A real reminder that arrives in a few seconds, for trying the buttons.
    public func test(_ kind: ReminderKind, child: ChildInfo, now: Date, delay: TimeInterval = 5) -> PlannedReminder {
        let fireDate = kind.isDailyQuestion ? now.addingTimeInterval(delay) : nil
        return PlannedReminder(
            id: ReminderIDs.test(kind),
            trigger: .after(delay),
            title: ReminderCopy.title(kind, childName: child.name),
            body: ReminderCopy.body(kind),
            payload: ReminderPayload(kind: kind, childID: child.id, fireDate: fireDate)
        )
    }

    /// The day a daily question is about. A skin answer given in the evening counts
    /// for the day that just ended, so a late skin check-in belongs to that day too.
    func questionDay(_ kind: ReminderKind, firing fireDate: Date) -> CareDay {
        kind == .skinCheckIn
            ? SkinDay.day(for: fireDate, calendar: calendar)
            : CareDay.containing(fireDate, calendar: calendar)
    }

    /// One-off reminders for the next 14 days, skipping days already answered.
    private func questions(
        _ kind: ReminderKind,
        at slot: ReminderSlot,
        child: ChildInfo,
        answered: Set<CareDay>,
        now: Date
    ) -> [PlannedReminder] {
        let today = calendar.startOfDay(for: now)
        let upcoming = (0...Self.checkInDays)
            .compactMap { offset -> Date? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
                return calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day)
            }
            .filter { $0 > now }
            .prefix(Self.checkInDays)

        return upcoming.compactMap { fireDate in
            let careDay = questionDay(kind, firing: fireDate)
            guard !answered.contains(careDay) else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            return PlannedReminder(
                id: ReminderIDs.question(kind, for: careDay),
                trigger: .once(parts),
                title: ReminderCopy.title(kind, childName: child.name),
                body: ReminderCopy.body(kind),
                payload: ReminderPayload(kind: kind, childID: child.id, fireDate: fireDate)
            )
        }
    }
}

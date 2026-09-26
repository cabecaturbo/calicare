import Foundation
import UserNotifications

/// The parts of the notification center reminders use. Faked in tests.
public protocol NotificationScheduling: Sendable {
    func isAuthorized() async -> Bool
    func pendingIDs() async -> [String]
    func add(_ reminder: PlannedReminder) async throws
    func removePending(_ ids: [String]) async
    func removeDelivered(_ ids: [String]) async
}

/// The real notification center.
public struct LiveNotificationCenter: NotificationScheduling {
    public init() {}

    /// Registers the notification buttons. None of them open the app.
    public static func registerCategories() {
        let checkIn = UNNotificationCategory(
            identifier: ReminderIDs.checkInCategory,
            actions: [ReminderAction.good, .okay, .rough].map(Self.action),
            intentIdentifiers: [],
            options: []
        )
        let routine = UNNotificationCategory(
            identifier: ReminderIDs.routineCategory,
            actions: [ReminderAction.done, .snooze].map(Self.action),
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([checkIn, routine])
    }

    public func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    public func pendingIDs() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    public func add(_ reminder: PlannedReminder) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.categoryIdentifier = reminder.kind.categoryID
        content.threadIdentifier = reminder.kind.threadID
        content.userInfo = reminder.payload.userInfo
        // No sound: calm, and it won't wake a sleeping child.
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: reminder.id,
            content: content,
            trigger: Self.trigger(for: reminder.trigger)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    public func removePending(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    public func removeDelivered(_ ids: [String]) async {
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    private static func action(_ action: ReminderAction) -> UNNotificationAction {
        // Empty options: runs in the background and works from the Lock Screen.
        UNNotificationAction(identifier: action.identifier, title: action.title, options: [])
    }

    private static func trigger(for trigger: PlannedReminder.Trigger) -> UNNotificationTrigger {
        switch trigger {
        case .once(let parts):
            UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        case .daily(let hour, let minute):
            UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        case .after(let seconds):
            UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        }
    }
}

import Core
import Foundation
import UserNotifications

/// "Remind me later" on the guide's last screen. iOS has no way for an app to
/// open the Lock Screen editor, so this sends one notification an hour later
/// that opens the guide again.
enum LockWidgetReminder {
    static let id = "calicare.lockGuide"
    static let linkKey = "link"
    static let delay: TimeInterval = 60 * 60

    /// False when notifications aren't allowed (asks once if undecided).
    @MainActor
    static func schedule(using reminders: ReminderController) async -> Bool {
        guard await reminders.ensureAllowed() else { return false }
        let content = UNMutableNotificationContent()
        content.title = ReminderCopy.lockWidgetTitle
        content.body = ReminderCopy.lockWidgetBody
        content.userInfo = [linkKey: DeepLink.lockGuide.absoluteString]
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    /// The link a tapped notification carries, if it's this one.
    static func link(in userInfo: [AnyHashable: Any]) -> URL? {
        (userInfo[linkKey] as? String).flatMap(URL.init(string:))
    }
}

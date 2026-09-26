import Core
import UIKit
import UserNotifications

/// Handles reminder buttons. iOS launches the app in the background for them,
/// even when it was closed, so the delegate is set as early as possible.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        LiveNotificationCenter.registerCategories()
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let payload = ReminderPayload(userInfo: response.notification.request.content.userInfo)
        do {
            try await NotificationActionHandler.live().handle(actionIdentifier: actionIdentifier, payload: payload)
        } catch {
            print("Reminder action failed: \(error)")
        }
    }

    /// Shows reminders even while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}

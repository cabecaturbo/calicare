import Foundation
import UserNotifications

/// Reads and asks for notification permission.
enum NotificationPermission {
    static func status() async -> UNAuthorizationStatus {
        if let stand = DesignReviewStandIn.current, stand.asked { return stand.status }
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Shows the system prompt (only the first time). Returns whether it's allowed.
    static func request() async -> Bool {
        if var stand = DesignReviewStandIn.current {
            stand.asked = true
            DesignReviewStandIn.current = stand
            return stand.status == .authorized
        }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])) ?? false
    }
}

/// Debug screenshots only (`-designReviewNotifications allow|deny`): the
/// simulator's permission prompt doesn't appear under UI tests, so this
/// answers it the same way every run.
private struct DesignReviewStandIn {
    var status: UNAuthorizationStatus
    var asked = false

    nonisolated(unsafe) static var current: DesignReviewStandIn? = {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "designReviewNotifications") {
        case "allow": DesignReviewStandIn(status: .authorized)
        case "deny": DesignReviewStandIn(status: .denied)
        default: nil
        }
        #else
        nil
        #endif
    }()
}

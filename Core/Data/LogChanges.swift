import Foundation
import WidgetKit

/// What to do after logs, children, or the current child change, from any process.
public enum LogChanges {
    /// Something on this phone changed: refresh what shows it, and tell the
    /// app (if this is the app) so it can sync a few seconds later.
    public static func didChange() async {
        await refreshDisplays()
        await MainActor.run {
            NotificationCenter.default.post(name: .caliCareLocalDataChanged, object: nil)
        }
    }

    /// Sync brought in changes from another phone: refresh without syncing again.
    public static func didReceiveRemoteChanges() async {
        await refreshDisplays()
        await MainActor.run {
            NotificationCenter.default.post(name: .caliCareRemoteDataChanged, object: nil)
        }
    }

    /// Refreshes widgets, and reschedules reminders so a night rating skips
    /// that morning's check-in (and an undo brings it back). Rescheduling runs
    /// on its own: the notification service can be slow to answer (on a fresh
    /// simulator it sometimes never does), and saving must never wait on it.
    public static func refreshDisplays() async {
        await reloadWidgets()
        // The Tonight card (only in the app's process; elsewhere it waits for the next tap or app open).
        await Tonight.refresh()
        Task.detached(priority: .utility) {
            try? await ReminderScheduler.live().refresh()
        }
    }

    @MainActor
    public static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension Notification.Name {
    /// Posted in-process after a local write (the app listens to sync soon).
    public static let caliCareLocalDataChanged = Notification.Name("CaliCareLocalDataChanged")
    /// Posted after sync applied changes from another phone.
    public static let caliCareRemoteDataChanged = Notification.Name("CaliCareRemoteDataChanged")
}

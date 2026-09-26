import Foundation
import WidgetKit

/// What to do after logs, children, or the current child change, from any process.
public enum LogChanges {
    /// Refreshes widgets, and reschedules reminders so a night rating skips
    /// that morning's check-in (and an undo brings it back).
    public static func didChange() async {
        await reloadWidgets()
        try? await ReminderScheduler.live().refresh()
    }

    @MainActor
    public static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

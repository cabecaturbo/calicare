import AppIntents
import Foundation
import WidgetKit

/// Shared steps for the logging intents.
enum IntentSupport {
    /// Logs through the shared database and returns what Siri should say.
    static func log(_ type: LogType, value: LogValue? = nil, child: ChildEntity?) async throws -> IntentDialog {
        let text = try await QuickLog.live().log(type, value: value, childID: child?.id)
        await afterChange()
        return "\(text)"
    }

    static func undo() async throws -> IntentDialog {
        let text = try await QuickLog.live().undoRecent()
        await afterChange()
        return "\(text)"
    }

    /// After any log or undo: refresh widgets, and reschedule reminders so a
    /// night rating skips that morning's check-in (and an undo brings it back).
    static func afterChange() async {
        await reloadWidgets()
        try? await ReminderScheduler.live().refresh()
    }

    @MainActor
    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

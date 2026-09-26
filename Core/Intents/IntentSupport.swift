import AppIntents
import Foundation
import WidgetKit

/// Shared steps for the logging intents.
enum IntentSupport {
    /// Logs through the shared database and returns what Siri should say.
    static func log(_ type: LogType, value: LogValue? = nil, child: ChildEntity?) async throws -> IntentDialog {
        let text = try await QuickLog.live().log(type, value: value, childID: child?.id)
        await reloadWidgets()
        return "\(text)"
    }

    static func undo() async throws -> IntentDialog {
        let text = try await QuickLog.live().undoRecent()
        await reloadWidgets()
        return "\(text)"
    }

    @MainActor
    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

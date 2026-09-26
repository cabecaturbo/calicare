import AppIntents
import Foundation

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

    static func afterChange() async {
        await LogChanges.didChange()
    }

    static func reloadWidgets() async {
        await LogChanges.reloadWidgets()
    }
}

import AppIntents

/// Removes the newest log if it's from the last 10 minutes, and says what it removed.
public struct UndoLastIntent: AppIntent {
    public static let title: LocalizedStringResource = "Undo Last Log"
    public static let description = IntentDescription("Removes the most recent log from the last 10 minutes.")
    public static let openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let dialog = try await IntentSupport.undo()
        return .result(dialog: dialog)
    }
}

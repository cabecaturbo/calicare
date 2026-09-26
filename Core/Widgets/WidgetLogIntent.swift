import AppIntents

/// The buttons on the widgets.
public enum WidgetAction: String, CaseIterable, AppEnum {
    case itchy, roughNight, bowelMovement, routineDone

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Log"
    public static let caseDisplayRepresentations: [WidgetAction: DisplayRepresentation] = [
        .itchy: "Itchy",
        .roughNight: "Rough night",
        .bowelMovement: "Bowel movement",
        .routineDone: "Routine done",
    ]

    public var logType: LogType {
        switch self {
        case .itchy: .itchEpisode
        case .roughNight: .nightRating
        case .bowelMovement: .bowelMovement
        case .routineDone: .routineDone
        }
    }

    public var value: LogValue? {
        self == .roughNight ? .night(.rough) : nil
    }
}

/// A widget button tap: logs with source `.widget`, then shows "Logged" with Undo.
/// Hidden from Shortcuts; Siri and Shortcuts use the other intents.
public struct WidgetLogIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log from Widget"
    public static let isDiscoverable = false
    public static let openAppWhenRun = false

    @Parameter(title: "Action")
    public var action: WidgetAction

    @Parameter(title: "Child")
    public var child: ChildEntity?

    public init() {}

    public init(action: WidgetAction, child: ChildEntity?) {
        self.action = action
        self.child = child
    }

    public func perform() async throws -> some IntentResult {
        let saved = try await QuickLog.live().record(
            action.logType, value: action.value, childID: child?.id, source: .widget
        )
        WidgetFeedbackStore().latest = WidgetFeedback(
            logID: saved.entry.id,
            childID: saved.child.id,
            title: LogPhrases().title(for: saved.entry),
            loggedAt: saved.entry.timestamp
        )
        await IntentSupport.reloadWidgets()
        return .result()
    }
}

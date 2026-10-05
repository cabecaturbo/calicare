import AppIntents

/// The buttons on the widgets.
public enum WidgetAction: String, CaseIterable, AppEnum {
    case itchy, roughNight, bowelMovement, routineDone, flare

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Log"
    public static let caseDisplayRepresentations: [WidgetAction: DisplayRepresentation] = [
        .itchy: "Itchy",
        .roughNight: "Rough night",
        .bowelMovement: "Bowel movement",
        .routineDone: "Routine done",
        .flare: "Flare",
    ]

    public var logType: LogType {
        switch self {
        case .itchy: .itchEpisode
        case .roughNight: .nightRating
        case .bowelMovement: .bowelMovement
        case .routineDone: .routineDone
        case .flare: .flare
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
    /// Spelled out (it's also the default): Lock Screen taps should run without
    /// Face ID if the system allows it at all.
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

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
        LockScreenDiagnostics.note("Widget \(action.rawValue) tapped. Data available: \(LockScreenDiagnostics.protectedDataAvailable)")
        let saved: QuickLog.Saved
        do {
            saved = try await Self.record(action, childID: child?.id)
        } catch {
            LockScreenDiagnostics.note("Widget \(action.rawValue) failed: \(error)")
            throw error
        }
        LockScreenDiagnostics.note("Widget \(action.rawValue) saved at \(saved.entry.timestamp.formatted(date: .omitted, time: .standard))")
        WidgetFeedbackStore().latest = WidgetFeedback(
            logID: saved.entry.id,
            childID: saved.child.id,
            title: LogPhrases().title(for: saved.entry),
            loggedAt: saved.entry.timestamp
        )
        await IntentSupport.afterChange()
        return .result()
    }

    /// Logs for the widget's child. If that child is gone (removed, or the
    /// widget's snapshot is stale) and there's only one child, logs for them;
    /// with two or more, it never guesses.
    static func record(_ action: WidgetAction, childID: UUID?) async throws -> QuickLog.Saved {
        let quick = try QuickLog.live()
        do {
            return try await quick.record(action.logType, value: action.value, childID: childID, source: .widget)
        } catch QuickLogError.childNotFound {
            let children = try await ChildStore(modelContainer: try CaliCareModelContainer.shared()).activeChildren()
            guard children.count == 1 else { throw QuickLogError.childNotFound }
            LockScreenDiagnostics.note("Widget child was stale; logged for the only child.")
            return try await quick.record(action.logType, value: action.value, childID: children[0].id, source: .widget)
        }
    }
}

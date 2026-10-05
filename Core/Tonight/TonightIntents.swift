import AppIntents
import Foundation

/// Tonight's Log button. A LiveActivityIntent, so the system runs it in the
/// app's process (launching it in the background if needed) and it can restart
/// the activity. Saves through the same path as the widgets.
public struct TonightLogIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Log a Wake-Up Tonight"
    public static let isDiscoverable = false
    public static let openAppWhenRun = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Child")
    public var childID: String

    public init() {}

    public init(childID: UUID) {
        self.childID = childID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        LockScreenDiagnostics.note("Tonight Log tapped. Data available: \(LockScreenDiagnostics.protectedDataAvailable)")
        do {
            let saved = try await WidgetLogIntent.record(.itchy, childID: UUID(uuidString: childID))
            await IntentSupport.afterChange()
            await Tonight.refresh(justLogged: saved.entry.timestamp)
            LockScreenDiagnostics.note("Tonight saved at \(saved.entry.timestamp.formatted(date: .omitted, time: .standard))")
            await Tonight.clearFeedback()
        } catch {
            LockScreenDiagnostics.note("Tonight Log failed: \(error)")
            throw error
        }
        return .result()
    }
}

/// Undo on the Tonight card: removes the log just made (10-minute window, like the widgets).
public struct TonightUndoIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Undo Tonight's Last Log"
    public static let isDiscoverable = false
    public static let openAppWhenRun = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    public init() {}

    public func perform() async throws -> some IntentResult {
        _ = try await QuickLog.live().undoRecent()
        await IntentSupport.afterChange()
        LockScreenDiagnostics.note("Tonight Undo.")
        return .result()
    }
}

/// "Start tonight in Cali Care": puts the Tonight card on the Lock Screen for
/// the current child.
public struct StartTonightIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Start Tonight"
    public static let description = IntentDescription("Puts a Log button and tonight's wake-ups on the Lock Screen.")
    public static let openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await Tonight.start()
            return .result(dialog: "Tonight is on your Lock Screen.")
        } catch TonightError.turnedOff {
            return .result(dialog: "Tonight is turned off in Cali Care's Settings.")
        } catch TonightError.activitiesOff {
            return .result(dialog: "Live Activities are off for Cali Care. You can turn them on in the Settings app.")
        } catch TonightError.noChild {
            return .result(dialog: "Add your child in Cali Care first.")
        }
    }
}

/// Takes the Tonight card off the Lock Screen.
public struct EndTonightIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "End Tonight"
    public static let openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        await Tonight.endAll()
        return .result(dialog: "Tonight is off the Lock Screen.")
    }
}

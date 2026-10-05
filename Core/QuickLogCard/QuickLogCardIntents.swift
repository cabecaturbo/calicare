import AppIntents
import Foundation

/// The Quick Log card's Log button. A LiveActivityIntent, so the system runs
/// it in the app's process (launching it in the background if needed) and it
/// can restart the card. Saves through the same path as the widgets.
public struct QuickLogCardLogIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Log from Quick Log"
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
        LockScreenDiagnostics.note("Quick Log tapped. Data available: \(LockScreenDiagnostics.protectedDataAvailable)")
        do {
            let saved = try await WidgetLogIntent.record(.itchy, childID: UUID(uuidString: childID))
            await IntentSupport.afterChange()
            await QuickLogCard.refresh(justLogged: saved.entry.timestamp)
            LockScreenDiagnostics.note("Quick Log saved at \(saved.entry.timestamp.formatted(date: .omitted, time: .standard))")
            await QuickLogCard.clearFeedback()
        } catch {
            LockScreenDiagnostics.note("Quick Log failed: \(error)")
            throw error
        }
        return .result()
    }
}

/// Undo on the card: removes the log just made (10-minute window, like the widgets).
public struct QuickLogCardUndoIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Undo Quick Log"
    public static let isDiscoverable = false
    public static let openAppWhenRun = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    public init() {}

    public func perform() async throws -> some IntentResult {
        _ = try await QuickLog.live().undoRecent()
        await IntentSupport.afterChange()
        LockScreenDiagnostics.note("Quick Log Undo.")
        return .result()
    }
}

/// "Start Quick Log in Cali Care": puts the card on the Lock Screen for the current child.
public struct StartQuickLogIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Start Quick Log"
    public static let description = IntentDescription("Puts a Log button and today's or tonight's count on the Lock Screen.")
    public static let openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await QuickLogCard.start()
            return .result(dialog: "Quick Log is on your Lock Screen.")
        } catch QuickLogCardError.turnedOff {
            return .result(dialog: "Quick Log is turned off in Cali Care's Settings.")
        } catch QuickLogCardError.activitiesOff {
            return .result(dialog: "Live Activities are off for Cali Care. You can turn them on in the Settings app.")
        } catch QuickLogCardError.noChild {
            return .result(dialog: "Add your child in Cali Care first.")
        }
    }
}

/// Takes the card off the Lock Screen.
public struct EndQuickLogIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "End Quick Log"
    public static let openAppWhenRun = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        await QuickLogCard.endAll()
        return .result(dialog: "Quick Log is off the Lock Screen.")
    }
}

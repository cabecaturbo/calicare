import ActivityKit
import AppIntents
import Foundation

/// Phase 0 test only (debug builds start it): a bare Live Activity with a Log
/// button, to learn on a real iPhone whether a Live Activity button saves a log
/// while the phone is locked. Shows a count and times, never a name.
public struct LockScreenTestAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var count: Int
        public var last: Date?

        public init(count: Int, last: Date?) {
            self.count = count
            self.last = last
        }
    }

    public init() {}
}

/// The test Live Activity's Log button. As a LiveActivityIntent it runs in the
/// app's process (launched in the background if needed), not the widget extension.
public struct LockScreenTestLogIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Log a Wake-Up (Test)"
    public static let isDiscoverable = false
    public static let openAppWhenRun = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    public init() {}

    public func perform() async throws -> some IntentResult {
        LockScreenDiagnostics.note("Live Activity tapped. Data available: \(LockScreenDiagnostics.protectedDataAvailable)")
        do {
            let saved = try await WidgetLogIntent.record(.itchy, childID: nil)
            LockScreenDiagnostics.note("Live Activity saved at \(saved.entry.timestamp.formatted(date: .omitted, time: .standard))")
            for activity in Activity<LockScreenTestAttributes>.activities {
                let state = LockScreenTestAttributes.ContentState(count: activity.content.state.count + 1, last: saved.entry.timestamp)
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
            await IntentSupport.afterChange()
        } catch {
            LockScreenDiagnostics.note("Live Activity failed: \(error)")
            throw error
        }
        return .result()
    }
}

/// Starts and ends the test activity from Settings › Debug.
public enum LockScreenTest {
    @MainActor
    public static func start() async throws {
        await end()
        _ = try Activity.request(
            attributes: LockScreenTestAttributes(),
            content: ActivityContent(state: .init(count: 0, last: nil), staleDate: nil),
            pushType: nil
        )
        LockScreenDiagnostics.note("Test Live Activity started.")
    }

    @MainActor
    public static func end() async {
        for activity in Activity<LockScreenTestAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        LockScreenDiagnostics.note("Test Live Activity ended.")
    }

    public static var isRunning: Bool { !Activity<LockScreenTestAttributes>.activities.isEmpty }
    public static var areEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
}

import ActivityKit
import Foundation

/// The "Tonight" Live Activity: what it shows, and starting, refreshing, and
/// ending it. The Lock Screen is public, so it carries counts and times only,
/// never a name.
public struct TonightAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        /// Wake-up times tonight, oldest first.
        public var wakeUps: [Date]
        /// "Logged 2:14 AM" with Undo, for a few seconds after a tap.
        public var justLogged: Date?
        /// When this activity's 8 hours run out, if before the morning.
        public var endsEarlyAt: Date?

        public init(wakeUps: [Date], justLogged: Date? = nil, endsEarlyAt: Date? = nil) {
            self.wakeUps = wakeUps
            self.justLogged = justLogged
            self.endsEarlyAt = endsEarlyAt
        }
    }

    /// Whose night (never shown), and its 7 PM–7 AM window.
    public let childID: UUID
    public let nightStart: Date
    public let nightEnd: Date

    public init(childID: UUID, nightStart: Date, nightEnd: Date) {
        self.childID = childID
        self.nightStart = nightStart
        self.nightEnd = nightEnd
    }
}

/// Settings › "Show Tonight on the Lock Screen". On unless turned off.
public struct TonightSettings: Sendable {
    private static let key = "tonight.enabled"

    public init() {}

    public var isEnabled: Bool {
        get { UserDefaults(suiteName: AppGroup.identifier)?.object(forKey: Self.key) as? Bool ?? true }
        nonmutating set { UserDefaults(suiteName: AppGroup.identifier)?.set(newValue, forKey: Self.key) }
    }
}

public enum TonightError: Error, Equatable {
    case turnedOff
    case activitiesOff
    case noChild
}

/// Starts, refreshes, and ends Tonight. Works in the app's process (the app,
/// or a LiveActivityIntent the system runs in it); in the widget extension it
/// does nothing, and the card catches up on the next tap or app open.
public enum Tonight {
    /// A Live Activity can run 8 hours (ActivityKit). Restarting it after this
    /// long keeps a night with wake-ups alive until morning.
    static let maxActive: TimeInterval = 8 * 3600
    static let restartAfter: TimeInterval = 30 * 60
    /// How long "Logged 2:14 AM · Undo" shows.
    public static let feedbackSeconds: Double = 5

    public static var current: Activity<TonightAttributes>? {
        Activity<TonightAttributes>.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    public static var isRunning: Bool { current != nil }

    public static var canRun: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Starts Tonight for a child (the current one when nil), replacing any running one.
    @discardableResult
    public static func start(childID: UUID? = nil, now: Date = .now) async throws -> UUID {
        guard TonightSettings().isEnabled else { throw TonightError.turnedOff }
        guard canRun else { throw TonightError.activitiesOff }
        let container = try CaliCareModelContainer.shared()
        let children = ChildStore(modelContainer: container)
        let child: ChildInfo?
        if let childID {
            child = try await children.activeChildren().first { $0.id == childID }
        } else {
            child = try await children.currentChild()
        }
        guard let child else { throw TonightError.noChild }
        await endAll()
        try await request(childID: child.id, now: now, justLogged: nil)
        LockScreenDiagnostics.note("Tonight started.")
        return child.id
    }

    /// After any log, undo, or sync: recount and update the card. Past the
    /// morning, shows the summary and lets it go. A tap that comes after
    /// `restartAfter` replaces the activity so it gets a fresh 8 hours.
    public static func refresh(justLogged: Date? = nil, now: Date = .now) async {
        guard let activity = current else { return }
        let attributes = activity.attributes
        let state = await state(for: attributes, justLogged: justLogged, now: now)
        if now >= attributes.nightEnd {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(attributes.nightEnd.addingTimeInterval(3 * 3600))
            )
            return
        }
        let age = now.timeIntervalSince(startDate(of: activity, attributes: attributes))
        if justLogged != nil, age > restartAfter {
            await activity.end(nil, dismissalPolicy: .immediate)
            try? await request(childID: attributes.childID, now: now, justLogged: justLogged)
            return
        }
        await activity.update(ActivityContent(state: state, staleDate: staleDate(for: attributes, startedAt: startDate(of: activity, attributes: attributes))))
    }

    /// Clears "Logged · Undo" once it has shown long enough.
    public static func clearFeedback(after seconds: Double = feedbackSeconds) async {
        try? await Task.sleep(for: .seconds(seconds))
        guard let activity = current, activity.content.state.justLogged != nil else { return }
        var state = activity.content.state
        state.justLogged = nil
        await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
    }

    public static func endAll() async {
        for activity in Activity<TonightAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// The child Tonight is running for.
    public static var childID: UUID? { current?.attributes.childID }

    // MARK: - Private

    private static func request(childID: UUID, now: Date, justLogged: Date?) async throws {
        let day = TonightNight.day(at: now)
        let window = day.nightInterval()
        let attributes = TonightAttributes(childID: childID, nightStart: window.start, nightEnd: window.end)
        let state = await state(for: attributes, justLogged: justLogged, now: now, startedAt: now)
        _ = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: staleDate(for: attributes, startedAt: now)),
            pushType: nil
        )
        StartDates.set(now, for: childID)
    }

    /// Stale at the morning (the card shows the summary), or when the 8 hours
    /// run out first (the card says it ended and how to keep going).
    static func staleDate(for attributes: TonightAttributes, startedAt: Date) -> Date {
        min(attributes.nightEnd, startedAt.addingTimeInterval(maxActive))
    }

    private static func state(
        for attributes: TonightAttributes, justLogged: Date?, now: Date, startedAt: Date? = nil
    ) async -> TonightAttributes.ContentState {
        let day = TonightNight.day(at: attributes.nightStart.addingTimeInterval(60))
        var wakeUps: [Date] = []
        if let container = try? CaliCareModelContainer.shared() {
            let logs = LogStore(modelContainer: container)
            if let events = try? await logs.events(for: day, child: attributes.childID) {
                wakeUps = TonightNight(day: day, events: events).wakeUps
            }
        }
        let started = startedAt ?? StartDates.get(for: attributes.childID) ?? now
        let limit = started.addingTimeInterval(maxActive)
        return TonightAttributes.ContentState(
            wakeUps: wakeUps,
            justLogged: justLogged,
            endsEarlyAt: limit < attributes.nightEnd ? limit : nil
        )
    }

    private static func startDate(of activity: Activity<TonightAttributes>, attributes: TonightAttributes) -> Date {
        StartDates.get(for: attributes.childID) ?? attributes.nightStart
    }

    /// When the current activity was requested (ActivityKit doesn't say).
    private enum StartDates {
        static let key = "tonight.startedAt"
        static func set(_ date: Date, for child: UUID) {
            UserDefaults(suiteName: AppGroup.identifier)?.set(date.timeIntervalSince1970, forKey: key + child.uuidString)
        }
        static func get(for child: UUID) -> Date? {
            guard let value = UserDefaults(suiteName: AppGroup.identifier)?.object(forKey: key + child.uuidString) as? Double else { return nil }
            return Date(timeIntervalSince1970: value)
        }
    }
}

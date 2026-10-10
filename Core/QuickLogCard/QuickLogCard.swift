import ActivityKit
import Foundation

/// The Quick Log card: a Live Activity on the Lock Screen (and Dynamic Island)
/// with a Log button and the count for today or tonight. The Lock Screen is
/// public, so it carries counts and times only, never a name.
public struct QuickLogCardAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        /// Day (7 AM–7 PM) or night (7 PM–7 AM).
        public var kind: LogPeriod.Kind
        /// Itch log times in this period, oldest first.
        public var itches: [Date]
        /// When this period ends: the card shows its summary from then on.
        public var periodEnd: Date
        /// "Logged 2:14 AM" with Undo, for a few seconds after a tap.
        public var justLogged: Date?
        /// When this activity's 8 hours run out, if before the period ends.
        public var endsEarlyAt: Date?

        public init(kind: LogPeriod.Kind, itches: [Date], periodEnd: Date, justLogged: Date? = nil, endsEarlyAt: Date? = nil) {
            self.kind = kind
            self.itches = itches
            self.periodEnd = periodEnd
            self.justLogged = justLogged
            self.endsEarlyAt = endsEarlyAt
        }

        public var words: PeriodWords { PeriodWords(kind: kind, itches: itches) }
    }

    /// Whose log it is (never shown).
    public let childID: UUID

    public init(childID: UUID) {
        self.childID = childID
    }
}

/// Settings › "Show Quick Log on the Lock Screen". On unless turned off.
public struct QuickLogCardSettings: Sendable {
    private static let key = "quickLogCard.enabled"

    public init() {}

    public var isEnabled: Bool {
        get { UserDefaults(suiteName: AppGroup.identifier)?.object(forKey: Self.key) as? Bool ?? true }
        nonmutating set { UserDefaults(suiteName: AppGroup.identifier)?.set(newValue, forKey: Self.key) }
    }
}

public enum QuickLogCardError: Error, Equatable {
    case turnedOff
    case activitiesOff
    case noChild
}

/// Starts, refreshes, and ends the card. Works in the app's process (the app,
/// or a LiveActivityIntent the system runs in it); in the widget extension it
/// does nothing, and the card catches up on the next tap or app open.
public enum QuickLogCard {
    /// A Live Activity can run 8 hours (ActivityKit). A tap after
    /// `restartAfter`, or after the period has ended, replaces the activity
    /// so it gets a fresh 8 hours and the right period.
    static let maxActive: TimeInterval = 8 * 3600
    static let restartAfter: TimeInterval = 30 * 60
    /// How long "Logged 2:14 AM · Undo" shows.
    public static let feedbackSeconds: Double = 5

    public static var current: Activity<QuickLogCardAttributes>? {
        Activity<QuickLogCardAttributes>.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    public static var isRunning: Bool { current != nil }

    public static var canRun: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Starts the card for a child (the current one when nil), replacing any running one.
    @discardableResult
    public static func start(childID: UUID? = nil, now: Date = .now) async throws -> UUID {
        guard QuickLogCardSettings().isEnabled else { throw QuickLogCardError.turnedOff }
        guard canRun else { throw QuickLogCardError.activitiesOff }
        let children = ChildStore(modelContainer: try CaliCareModelContainer.shared())
        let child: ChildInfo?
        if let childID {
            child = try await children.activeChildren().first { $0.id == childID }
        } else {
            child = try await children.currentChild()
        }
        guard let child else { throw QuickLogCardError.noChild }
        await endAll()
        try await request(childID: child.id, now: now, justLogged: nil)
        LockScreenDiagnostics.note("Quick Log card started.")
        return child.id
    }

    /// After any log, undo, or sync: recount and update the card. A tap
    /// (`justLogged`) after `restartAfter`, or once the card's period is over,
    /// replaces it so it counts the right period with a fresh 8 hours.
    public static func refresh(justLogged: Date? = nil, now: Date = .now) async {
        guard let activity = current else { return }
        let childID = activity.attributes.childID
        let started = StartDates.get(for: childID) ?? now
        let periodOver = now >= activity.content.state.periodEnd
        if justLogged != nil, periodOver || now.timeIntervalSince(started) > restartAfter {
            await activity.end(nil, dismissalPolicy: .immediate)
            try? await request(childID: childID, now: now, justLogged: justLogged)
            return
        }
        if periodOver {
            // Keep showing the finished period's summary (with Log still there).
            return
        }
        let state = await state(childID: childID, now: now, startedAt: started, justLogged: justLogged)
        await activity.update(ActivityContent(state: state, staleDate: staleDate(state)))
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
        for activity in Activity<QuickLogCardAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// The child the card is running for.
    public static var childID: UUID? { current?.attributes.childID }

    // MARK: - Private

    private static func request(childID: UUID, now: Date, justLogged: Date?) async throws {
        let state = await state(childID: childID, now: now, startedAt: now, justLogged: justLogged)
        _ = try Activity.request(
            attributes: QuickLogCardAttributes(childID: childID),
            content: ActivityContent(state: state, staleDate: staleDate(state)),
            pushType: nil
        )
        StartDates.set(now, for: childID)
    }

    /// Stale when the period ends (the card shows its summary), or when the
    /// 8 hours run out first (the card says so).
    static func staleDate(_ state: QuickLogCardAttributes.ContentState) -> Date {
        state.endsEarlyAt ?? state.periodEnd
    }

    private static func state(
        childID: UUID, now: Date, startedAt: Date, justLogged: Date?
    ) async -> QuickLogCardAttributes.ContentState {
        let (kind, day) = LogPeriod.current(at: now)
        var itches: [Date] = []
        var periodEnd = kind == .night ? day.nightInterval().end : day.daytimeInterval().end
        if let container = try? CaliCareModelContainer.shared(),
           let events = try? await LogStore(modelContainer: container).events(for: day, child: childID) {
            let period = LogPeriod(kind: kind, day: day, events: events)
            itches = period.itches
            periodEnd = period.end
        }
        let limit = startedAt.addingTimeInterval(maxActive)
        return QuickLogCardAttributes.ContentState(
            kind: kind,
            itches: itches,
            periodEnd: periodEnd,
            justLogged: justLogged,
            endsEarlyAt: limit < periodEnd ? limit : nil
        )
    }

    /// When the current activity was requested (ActivityKit doesn't say).
    private enum StartDates {
        static let key = "quickLogCard.startedAt."
        static func set(_ date: Date, for child: UUID) {
            UserDefaults(suiteName: AppGroup.identifier)?.set(date.timeIntervalSince1970, forKey: key + child.uuidString)
        }
        static func get(for child: UUID) -> Date? {
            guard let value = UserDefaults(suiteName: AppGroup.identifier)?.object(forKey: key + child.uuidString) as? Double else { return nil }
            return Date(timeIntervalSince1970: value)
        }
    }
}

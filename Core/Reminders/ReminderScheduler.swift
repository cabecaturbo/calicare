import Foundation
import SwiftData

/// Keeps pending reminders in line with the settings, the current child, and
/// what's already logged. Safe to call often: from the app, widgets, and intents.
public struct ReminderScheduler: Sendable {
    private let center: any NotificationScheduling
    private let container: ModelContainer
    private let store: ReminderSettingsStore
    private let childSetting: CurrentChildSetting
    private let planner: ReminderPlanner
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        center: any NotificationScheduling,
        container: ModelContainer,
        store: ReminderSettingsStore = ReminderSettingsStore(),
        childSetting: CurrentChildSetting = CurrentChildSetting(),
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.center = center
        self.container = container
        self.store = store
        self.childSetting = childSetting
        self.planner = ReminderPlanner(calendar: calendar)
        self.calendar = calendar
        self.now = now
    }

    /// Uses the real notification center and the shared App Group database.
    public static func live() throws -> ReminderScheduler {
        ReminderScheduler(center: LiveNotificationCenter(), container: try CaliCareModelContainer.shared())
    }

    /// Replaces the planned reminders. Nothing is scheduled without permission or a child.
    /// A snooze stays unless its reminder was turned off.
    public func refresh() async throws {
        let settings = store.settings
        let current = now()
        let child = try await ChildStore(modelContainer: container, now: now).currentChild(setting: childSetting)
        let rated = try await ratedDays(child: child, now: current)
        let skin = try await skinDays(child: child, now: current)
        let authorized = await center.isAuthorized()
        // How many things each To do block holds, for "Bedtime: 5 things".
        var day: TodoDay?
        if let child { day = try? await TodoActions(container: container, now: now).day(child: child.id) }
        let things = day.map { day in Dictionary(day.blocks.map { ($0.block, $0.items.count) }, uniquingKeysWith: { a, _ in a }) }
        let planned = authorized
            ? planner.plan(settings: settings, child: child, ratedDays: rated, skinDays: skin, things: things, now: current)
            : []

        let stale = await center.pendingIDs().filter { id in
            if ReminderIDs.isPlanned(id) { return true }
            if let kind = ReminderIDs.snoozedKind(id) { return !settings[kind].isOn }
            return false
        }
        await center.removePending(stale)
        for reminder in planned {
            try await center.add(reminder)
        }
        // A check-in already on screen for a night that now has a rating isn't needed.
        await center.removeDelivered(rated.map(ReminderIDs.checkIn(for:)) + skin.map(ReminderIDs.skinCheckIn(for:)))
    }

    /// Brings the reminder back in 30 minutes.
    public func snooze(_ payload: ReminderPayload) async throws {
        let children = ChildStore(modelContainer: container, now: now)
        var child = try await children.activeChildren().first { $0.id == payload.childID }
        if child == nil {
            child = try await children.currentChild(setting: childSetting)
        }
        guard let child else { return }
        try await center.add(planner.snooze(payload, childName: child.name))
    }

    /// Sends a real reminder in a few seconds, for trying the buttons.
    public func sendTest(_ kind: ReminderKind) async throws {
        let children = ChildStore(modelContainer: container, now: now)
        guard let child = try await children.currentChild(setting: childSetting) else {
            throw QuickLogError.noChild
        }
        try await center.add(planner.test(kind, child: child, now: now()))
    }

    /// Days (today's skin day and the next) that already have a skin answer.
    private func skinDays(child: ChildInfo?, now current: Date) async throws -> Set<CareDay> {
        guard let child else { return [] }
        let logs = LogStore(modelContainer: container, calendar: calendar, now: now)
        let today = SkinDay.day(for: current, calendar: calendar)
        var answered: Set<CareDay> = []
        for day in [today, today.adding(days: 1, calendar: calendar)] {
            let events = try await logs.events(for: day, child: child.id)
            if events.contains(where: { $0.type == .skinToday }) {
                answered.insert(day)
            }
        }
        return answered
    }

    /// Care days (today and tomorrow) that already have a night rating.
    /// A rating logged after 7 PM counts toward tomorrow, so it skips tomorrow's check-in.
    private func ratedDays(child: ChildInfo?, now current: Date) async throws -> Set<CareDay> {
        guard let child else { return [] }
        let logs = LogStore(modelContainer: container, calendar: calendar, now: now)
        let today = CareDay.containing(current, calendar: calendar)
        var rated: Set<CareDay> = []
        for day in [today, today.adding(days: 1, calendar: calendar)] {
            let events = try await logs.events(for: day, child: child.id)
            if events.contains(where: { $0.type == .nightRating }) {
                rated.insert(day)
            }
        }
        return rated
    }
}

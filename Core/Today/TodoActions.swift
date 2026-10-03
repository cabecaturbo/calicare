import Foundation
import SwiftData

/// Reads a child's To do for now, and ticks a whole block ("All done" on a
/// reminder, without opening the app).
public struct TodoActions: Sendable {
    public let container: ModelContainer
    private let times: @Sendable () -> [TodoBlock: DateComponents]
    private let now: @Sendable () -> Date

    public init(container: ModelContainer, times: @escaping @Sendable () -> [TodoBlock: DateComponents] = { TodoTimes.current() },
                now: @escaping @Sendable () -> Date = { .now }) {
        self.container = container
        self.times = times
        self.now = now
    }

    public func day(child childID: UUID) async throws -> TodoDay {
        let steps = try await RoutineStore(modelContainer: container).steps(child: childID, includeInactive: true)
        let plans = CarePlanStore(modelContainer: container)
        var items: [PlanItemInfo] = []
        if let plan = try await plans.activePlan(child: childID) { items = try await plans.items(plan: plan.id) }
        let logs = try await LogStore(modelContainer: container).allLive().filter { $0.childID == childID }
        return TodoDay(steps: steps, items: items, logs: logs, times: times(), now: now())
    }

    /// Ticks everything not yet done in `block`. Skin care, if it's in that
    /// block and not done, gets one round. Returns how many things it ticked.
    @discardableResult
    public func completeBlock(_ block: TodoBlock, child childID: UUID, source: EntrySource) async throws -> Int {
        let day = try await day(child: childID)
        guard let items = day.blocks.first(where: { $0.block == block })?.items else { return 0 }
        var count = 0
        for item in items where !item.isDone {
            try await tick(item, in: block, day: day, child: childID, source: source)
            count += 1
        }
        return count
    }

    /// One tap on a row's circle.
    /// One tap on a row's circle. Skin care logs one round, on its first step.
    @discardableResult
    public func tick(_ item: TodoDay.Item, in block: TodoBlock, day: TodoDay, child childID: UUID,
                     source: EntrySource) async throws -> LogEntry? {
        let logs = LogStore(modelContainer: container)
        switch item.kind {
        case .step(let step):
            return try await logs.logRoutineStep(step.id, source: source, at: now())
        case .supplement(let plan):
            return try await logs.logSupplement(.taken, item: plan.id, child: childID, source: source, block: block, at: now())
        case .skin:
            guard let first = day.skin?.steps.first else { return nil }
            return try await logs.logRoutineStep(first.id, source: source, at: now())
        }
    }
}

/// The To do block times, from Settings › Reminders (the list reminders'
/// times, whether or not the reminder is on).
public enum TodoTimes {
    public static func current(_ store: ReminderSettingsStore = ReminderSettingsStore()) -> [TodoBlock: DateComponents] {
        let settings = store.settings
        var times: [TodoBlock: DateComponents] = [:]
        for kind in ReminderKind.allCases {
            guard let block = kind.todoBlock else { continue }
            let slot = settings[kind]
            times[block] = DateComponents(hour: slot.hour, minute: slot.minute)
        }
        return times
    }
}

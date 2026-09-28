import Foundation

/// How far along one routine (morning or evening) is today, for Plan.
public struct RoutineProgress: Hashable, Sendable {
    public let time: RoutineTime
    /// Active steps, in order. Empty when the parent hasn't set any.
    public let steps: [RoutineStepInfo]
    /// Today's log for each ticked-off step.
    public let doneLogs: [UUID: LogEntry]
    /// Today's latest "routine done" without a step (one tap, widget, Siri).
    public let wholeRoutineLog: LogEntry?

    /// `entries` are the care day's logs, any order.
    public init(time: RoutineTime, steps: [RoutineStepInfo], entries: [LogEntry]) {
        self.time = time
        self.steps = steps.filter { $0.time == time && $0.isActive }.sorted { $0.order < $1.order }
        let routineLogs = entries
            .filter { $0.type == .routineDone && $0.value == .routine(time) }
            .sorted { $0.timestamp > $1.timestamp }
        var done: [UUID: LogEntry] = [:]
        for log in routineLogs {
            if let id = log.routineStepID, done[id] == nil { done[id] = log }
        }
        doneLogs = done
        wholeRoutineLog = routineLogs.first { $0.routineStepID == nil }
    }

    public var left: Int {
        steps.filter { doneLogs[$0.id] == nil }.count
    }

    /// Done when every step is ticked, or (with no steps) when the routine was logged.
    public var isDone: Bool {
        steps.isEmpty ? wholeRoutineLog != nil : left == 0
    }

    /// "Evening · done", "Evening · 2 left", "Evening · 3 steps" (none ticked
    /// yet), or "Evening · not done yet" (no steps set).
    public var title: String {
        let name = time == .morning ? "Morning" : "Evening"
        if isDone { return "\(name) · done" }
        if steps.isEmpty { return "\(name) · not done yet" }
        if left == steps.count { return "\(name) · \(left) step\(left == 1 ? "" : "s")" }
        return "\(name) · \(left) left"
    }

    /// When it was finished: the whole-routine log, or the last step ticked.
    public var finishedAt: Date? {
        guard isDone else { return nil }
        if steps.isEmpty { return wholeRoutineLog?.timestamp }
        return doneLogs.values.map(\.timestamp).max()
    }
}

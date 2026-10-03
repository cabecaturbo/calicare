import Foundation
import SwiftData

/// Runs a reminder button in the background: logs through `QuickLog` with
/// source `.notification`, or snoozes. Tapping or dismissing does nothing.
public struct NotificationActionHandler: Sendable {
    public enum Outcome: Equatable, Sendable {
        case logged(LogEntry)
        case snoozed
        case completed(TodoBlock)
        case ignored
    }

    private let quickLog: QuickLog
    private let scheduler: ReminderScheduler
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let onChange: @Sendable () async -> Void
    /// Ticks a whole To do block; nil logs the routine as done instead.
    private let completeBlock: (@Sendable (TodoBlock, UUID) async throws -> Int)?

    public init(
        quickLog: QuickLog,
        scheduler: ReminderScheduler,
        completeBlock: (@Sendable (TodoBlock, UUID) async throws -> Int)? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now },
        onChange: @escaping @Sendable () async -> Void = {}
    ) {
        self.quickLog = quickLog
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
        self.onChange = onChange
        self.completeBlock = completeBlock
    }

    /// Uses the shared database and the real notification center, and refreshes widgets.
    public static func live() throws -> NotificationActionHandler {
        let actions = TodoActions(container: try CaliCareModelContainer.shared())
        return NotificationActionHandler(
            quickLog: try QuickLog.live(),
            scheduler: try ReminderScheduler.live(),
            completeBlock: { block, child in try await actions.completeBlock(block, child: child, source: .notification) },
            onChange: { await IntentSupport.reloadWidgets() }
        )
    }

    @discardableResult
    public func handle(actionIdentifier: String, payload: ReminderPayload?) async throws -> Outcome {
        guard let payload, let action = ReminderAction(identifier: actionIdentifier) else { return .ignored }

        switch action {
        case .good, .okay, .rough:
            guard payload.kind == .checkIn, let rating = action.nightRating else { return .ignored }
            return try await log(.nightRating, value: .night(rating), payload: payload, at: checkInTime(payload))
        case .done:
            // "All done": every open thing in that To do block, without opening the app.
            if let block = payload.kind.todoBlock, let completeBlock, let childID = payload.childID {
                _ = try await completeBlock(block, childID)
                await onChange()
                try await scheduler.refresh()
                return .completed(block)
            }
            guard let time = payload.kind.routineTime else { return .ignored }
            return try await log(.routineDone, value: .routine(time), payload: payload, at: nil)
        case .snooze:
            guard payload.kind.todoBlock != nil else { return .ignored }
            try await scheduler.snooze(payload)
            return .snoozed
        case .calm, .littleItchy, .flaring, .veryRough:
            guard payload.kind == .skinCheckIn, let answer = action.skinToday else { return .ignored }
            return try await log(.skinToday, value: .skin(answer), payload: payload, at: skinTime(payload))
        }
    }

    private func log(_ type: LogType, value: LogValue, payload: ReminderPayload, at timestamp: Date?) async throws -> Outcome {
        let saved: QuickLog.Saved
        do {
            saved = try await quickLog.record(type, value: value, childID: payload.childID, source: .notification, at: timestamp)
        } catch QuickLogError.childNotFound {
            // That child was removed since the reminder was sent; log for the current child.
            saved = try await quickLog.record(type, value: value, source: .notification, at: timestamp)
        }
        await onChange()
        try await scheduler.refresh()
        return .logged(saved.entry)
    }

    /// Now, unless the skin check-in is answered on a later day (say, the next
    /// morning). Then it's logged at the check-in's own time, for the day it asked about.
    private func skinTime(_ payload: ReminderPayload) -> Date? {
        guard let fireDate = payload.fireDate else { return nil }
        let answeredDay = SkinDay.day(for: now(), calendar: calendar)
        let reminderDay = SkinDay.day(for: fireDate, calendar: calendar)
        return answeredDay == reminderDay ? nil : fireDate
    }

    /// Now, unless the check-in is answered on a later care day. Then it's logged
    /// at the check-in's own time, so the rating lands on the right night.
    private func checkInTime(_ payload: ReminderPayload) -> Date? {
        guard let fireDate = payload.fireDate else { return nil }
        let answeredDay = CareDay.containing(now(), calendar: calendar)
        let reminderDay = CareDay.containing(fireDate, calendar: calendar)
        return answeredDay == reminderDay ? nil : fireDate
    }
}

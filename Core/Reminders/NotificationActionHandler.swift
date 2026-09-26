import Foundation
import SwiftData

/// Runs a reminder button in the background: logs through `QuickLog` with
/// source `.notification`, or snoozes. Tapping or dismissing does nothing.
public struct NotificationActionHandler: Sendable {
    public enum Outcome: Equatable, Sendable {
        case logged(LogEntry)
        case snoozed
        case ignored
    }

    private let quickLog: QuickLog
    private let scheduler: ReminderScheduler
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let onChange: @Sendable () async -> Void

    public init(
        quickLog: QuickLog,
        scheduler: ReminderScheduler,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now },
        onChange: @escaping @Sendable () async -> Void = {}
    ) {
        self.quickLog = quickLog
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
        self.onChange = onChange
    }

    /// Uses the shared database and the real notification center, and refreshes widgets.
    public static func live() throws -> NotificationActionHandler {
        NotificationActionHandler(
            quickLog: try QuickLog.live(),
            scheduler: try ReminderScheduler.live(),
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
            guard let time = payload.kind.routineTime else { return .ignored }
            return try await log(.routineDone, value: .routine(time), payload: payload, at: nil)
        case .snooze:
            guard payload.kind.routineTime != nil else { return .ignored }
            try await scheduler.snooze(payload)
            return .snoozed
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

    /// Now, unless the check-in is answered on a later care day. Then it's logged
    /// at the check-in's own time, so the rating lands on the right night.
    private func checkInTime(_ payload: ReminderPayload) -> Date? {
        guard let fireDate = payload.fireDate else { return nil }
        let answeredDay = CareDay.containing(now(), calendar: calendar)
        let reminderDay = CareDay.containing(fireDate, calendar: calendar)
        return answeredDay == reminderDay ? nil : fireDate
    }
}

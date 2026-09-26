import Foundation
import SwiftData

public enum LogStoreError: Error, Equatable, Sendable {
    /// The value doesn't fit the log type (e.g. a mood on a night rating).
    case invalidValue
    /// A note log needs text.
    case emptyNote
    case childNotFound
}

/// Reads and writes logs. Every write is saved right away, because widgets
/// and intents run in short-lived processes.
public actor LogStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        modelContainer: ModelContainer,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.calendar = calendar
        self.now = now
    }

    /// Saves one log. `at` defaults to now; pass it to log something earlier.
    @discardableResult
    public func log(
        _ type: LogType,
        value: LogValue? = nil,
        child childID: UUID,
        source: EntrySource,
        note: String? = nil,
        loggedBy: String = "Me",
        at timestamp: Date? = nil
    ) async throws -> LogEntry {
        guard type.accepts(value) else { throw LogStoreError.invalidValue }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = trimmedNote?.isEmpty == false ? trimmedNote : nil
        if type == .note, cleanNote == nil { throw LogStoreError.emptyNote }
        guard let child = try fetchChild(childID) else { throw LogStoreError.childNotFound }

        let current = now()
        let event = LogEvent(
            child: child,
            type: type,
            value: value,
            note: cleanNote,
            timestamp: timestamp ?? current,
            loggedBy: loggedBy,
            entrySource: source,
            now: current
        )
        modelContext.insert(event)
        try modelContext.save()
        return LogEntry(
            id: event.id,
            childID: childID,
            type: type,
            value: value,
            note: cleanNote,
            timestamp: event.timestamp,
            loggedBy: loggedBy,
            source: source
        )
    }

    /// Soft-deletes the most recently created log, for any child.
    /// Returns what was undone, or nil if there's nothing to undo.
    @discardableResult
    public func undoLast() async throws -> LogEntry? {
        var descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let event = try modelContext.fetch(descriptor).first else { return nil }
        let entry = LogEntry(event)
        let current = now()
        event.deletedAt = current
        event.updatedAt = current
        event.needsSync = true
        try modelContext.save()
        return entry
    }

    /// Live logs for one child on one care day (7 PM the evening before to 7 PM), oldest first.
    public func events(for day: CareDay, child childID: UUID) async throws -> [LogEntry] {
        let range = day.interval(calendar: calendar)
        let start = range.start
        let end = range.end
        let optionalChildID: UUID? = childID
        let descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { event in
                event.deletedAt == nil
                    && event.timestamp >= start
                    && event.timestamp < end
                    && event.child?.id == optionalChildID
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try modelContext.fetch(descriptor).compactMap { LogEntry($0) }
    }

    /// Summary of the current care day. From 7 PM this already means tonight and tomorrow.
    public func todaySummary(child childID: UUID) async throws -> DaySummary {
        let today = CareDay.containing(now(), calendar: calendar)
        let entries = try await events(for: today, child: childID)
        return DaySummary(day: today, events: entries, calendar: calendar)
    }

    private func fetchChild(_ id: UUID) throws -> Child? {
        var descriptor = FetchDescriptor<Child>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

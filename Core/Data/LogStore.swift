import Foundation
import SwiftData

public enum LogStoreError: Error, Equatable, Sendable {
    /// The value doesn't fit the log type (e.g. a mood on a night rating).
    case invalidValue
    /// A note log needs text.
    case emptyNote
    case childNotFound
    /// The log doesn't exist or was already deleted.
    case logNotFound
    /// Body areas only go on flares.
    case bodyAreasNotAllowed
    case routineStepNotFound
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
    ///
    /// A skin answer replaces that day's earlier answer, and one given at night
    /// counts for the day that just ended (see `SkinDay`).
    @discardableResult
    public func log(
        _ type: LogType,
        value: LogValue? = nil,
        child childID: UUID,
        source: EntrySource,
        note: String? = nil,
        bodyAreas: [BodyArea] = [],
        loggedBy: String = LoggedBy.current(),
        at timestamp: Date? = nil
    ) async throws -> LogEntry {
        try insert(
            type, value: value, child: childID, source: source, note: note,
            bodyAreas: bodyAreas, routineStepID: nil, loggedBy: loggedBy, at: timestamp
        )
    }

    /// Ticks off one routine step: a `routineDone` log for the step's morning or evening.
    @discardableResult
    public func logRoutineStep(
        _ stepID: UUID,
        source: EntrySource,
        loggedBy: String = LoggedBy.current(),
        at timestamp: Date? = nil
    ) async throws -> LogEntry {
        var descriptor = FetchDescriptor<RoutineStep>(
            predicate: #Predicate { $0.id == stepID && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        guard let step = try modelContext.fetch(descriptor).first, let time = step.time else {
            throw LogStoreError.routineStepNotFound
        }
        return try insert(
            .routineDone, value: .routine(time), child: step.childID, source: source, note: nil,
            bodyAreas: [], routineStepID: step.id, loggedBy: loggedBy, at: timestamp
        )
    }

    /// Sets where a flare was, after the fact ("Add where"). An empty list clears it.
    @discardableResult
    public func setBodyAreas(_ areas: [BodyArea], on id: UUID) async throws -> LogEntry {
        guard let event = try fetchLiveEvent(id) else { throw LogStoreError.logNotFound }
        guard event.type == .flare else { throw LogStoreError.bodyAreasNotAllowed }
        event.bodyAreaNames = Self.unique(areas).map(\.rawValue)
        event.updatedAt = now()
        event.needsSync = true
        try modelContext.save()
        guard let entry = LogEntry(event) else { throw LogStoreError.logNotFound }
        return entry
    }

    private func insert(
        _ type: LogType,
        value: LogValue?,
        child childID: UUID,
        source: EntrySource,
        note: String?,
        bodyAreas: [BodyArea],
        routineStepID: UUID?,
        loggedBy: String,
        at timestamp: Date?
    ) throws -> LogEntry {
        guard type.accepts(value) else { throw LogStoreError.invalidValue }
        if !bodyAreas.isEmpty, type != .flare { throw LogStoreError.bodyAreasNotAllowed }
        let cleanNote = Self.clean(note)
        if type == .note, cleanNote == nil { throw LogStoreError.emptyNote }
        guard let child = try fetchChild(childID) else { throw LogStoreError.childNotFound }

        let current = now()
        var when = timestamp ?? current
        if type == .skinToday {
            when = SkinDay.timestamp(for: when, calendar: calendar)
            try retireSkinAnswers(child: childID, on: CareDay.containing(when, calendar: calendar), at: current)
        }
        let event = LogEvent(
            child: child,
            type: type,
            value: value,
            note: cleanNote,
            timestamp: when,
            loggedBy: loggedBy,
            entrySource: source,
            bodyAreas: Self.unique(bodyAreas),
            routineStepID: routineStepID,
            now: current
        )
        modelContext.insert(event)
        try modelContext.save()
        guard let entry = LogEntry(event) else { throw LogStoreError.logNotFound }
        return entry
    }

    /// One skin answer per child per day: earlier answers that day are soft-deleted
    /// (not edited), so Undo on the new answer leaves the day unanswered.
    private func retireSkinAnswers(child childID: UUID, on day: CareDay, at current: Date) throws {
        let interval = day.interval(calendar: calendar)
        let start = interval.start
        let end = interval.end
        let raw = LogType.skinToday.rawValue
        let optionalChildID: UUID? = childID
        let descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { event in
                event.deletedAt == nil
                    && event.typeRaw == raw
                    && event.timestamp >= start
                    && event.timestamp < end
                    && event.child?.id == optionalChildID
            }
        )
        for event in try modelContext.fetch(descriptor) {
            event.deletedAt = current
            event.updatedAt = current
            event.needsSync = true
        }
    }

    /// Soft-deletes the most recently created log, for any child.
    /// With a `window`, only undoes it if it was created at most that long ago;
    /// older logs are never reached. Returns what was undone, or nil.
    @discardableResult
    public func undoLast(within window: TimeInterval? = nil) async throws -> LogEntry? {
        var descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let event = try modelContext.fetch(descriptor).first else { return nil }
        let current = now()
        if let window, current.timeIntervalSince(event.createdAt) > window { return nil }
        let entry = LogEntry(event)
        event.deletedAt = current
        event.updatedAt = current
        event.needsSync = true
        try modelContext.save()
        return entry
    }

    /// Live logs for one child on one care day (7 PM the evening before to 7 PM), oldest first.
    public func events(for day: CareDay, child childID: UUID) async throws -> [LogEntry] {
        try await events(from: day, through: day, child: childID)
    }

    /// Live logs for one child from the start of `first` to the end of `last`, oldest first.
    public func events(from first: CareDay, through last: CareDay, child childID: UUID) async throws -> [LogEntry] {
        let start = first.interval(calendar: calendar).start
        let end = last.interval(calendar: calendar).end
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

    /// Changes a log's value, note, and time. The type, child, and source stay.
    @discardableResult
    public func update(_ id: UUID, value: LogValue?, note: String?, timestamp: Date) async throws -> LogEntry {
        guard let event = try fetchLiveEvent(id), let type = event.type else { throw LogStoreError.logNotFound }
        guard type.accepts(value) else { throw LogStoreError.invalidValue }
        let cleanNote = Self.clean(note)
        if type == .note, cleanNote == nil { throw LogStoreError.emptyNote }

        event.valueRaw = value?.rawValue
        event.note = cleanNote
        event.timestamp = timestamp
        event.updatedAt = now()
        event.needsSync = true
        try modelContext.save()
        guard let entry = LogEntry(event) else { throw LogStoreError.logNotFound }
        return entry
    }

    /// Soft-deletes one log. Returns what was deleted, or nil if it was already gone.
    @discardableResult
    public func delete(_ id: UUID) async throws -> LogEntry? {
        guard let event = try fetchLiveEvent(id) else { return nil }
        let entry = LogEntry(event)
        let current = now()
        event.deletedAt = current
        event.updatedAt = current
        event.needsSync = true
        try modelContext.save()
        return entry
    }

    /// Brings back a log deleted by mistake (Undo after a swipe). Returns nil if it's gone for good.
    @discardableResult
    public func restore(_ id: UUID) async throws -> LogEntry? {
        var descriptor = FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == id && $0.deletedAt != nil })
        descriptor.fetchLimit = 1
        guard let event = try modelContext.fetch(descriptor).first else { return nil }
        event.deletedAt = nil
        event.updatedAt = now()
        event.needsSync = true
        try modelContext.save()
        return LogEntry(event)
    }

    /// Summary of the current care day. From 7 PM this already means tonight and tomorrow.
    public func todaySummary(child childID: UUID) async throws -> DaySummary {
        let today = CareDay.containing(now(), calendar: calendar)
        let entries = try await events(for: today, child: childID)
        return DaySummary(day: today, events: entries, calendar: calendar)
    }

    /// The newest live log of one type for one child, by when it happened.
    public func latest(_ type: LogType, child childID: UUID) async throws -> LogEntry? {
        let raw = type.rawValue
        let optionalChildID: UUID? = childID
        var descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { event in
                event.deletedAt == nil && event.typeRaw == raw && event.child?.id == optionalChildID
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.flatMap { LogEntry($0) }
    }

    /// Whether a log exists and hasn't been undone or deleted.
    public func isLive(_ id: UUID) async throws -> Bool {
        let descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        return try modelContext.fetchCount(descriptor) > 0
    }

    /// Every live log, for every child, oldest first. For "Your data" export.
    public func allLive() async throws -> [LogEntry] {
        let descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try modelContext.fetch(descriptor).compactMap { LogEntry($0) }
    }

    /// The most recently created live logs, for any child, newest first.
    public func recent(limit: Int = 50) async throws -> [LogEntry] {
        var descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).compactMap { LogEntry($0) }
    }

    private func fetchLiveEvent(_ id: UUID) throws -> LogEvent? {
        var descriptor = FetchDescriptor<LogEvent>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Each area once, in the order given.
    private static func unique(_ areas: [BodyArea]) -> [BodyArea] {
        var seen = Set<BodyArea>()
        return areas.filter { seen.insert($0).inserted }
    }

    /// Trimmed, or nil when empty.
    private static func clean(_ note: String?) -> String? {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func fetchChild(_ id: UUID) throws -> Child? {
        var descriptor = FetchDescriptor<Child>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

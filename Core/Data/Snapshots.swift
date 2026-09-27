import Foundation

/// A read-only copy of a log, safe to pass between actors and processes.
public struct LogEntry: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let childID: UUID?
    public let type: LogType
    public let value: LogValue?
    public let note: String?
    public let timestamp: Date
    public let loggedBy: String
    public let source: EntrySource
    /// Where a flare was, if the parent said.
    public let bodyAreas: [BodyArea]
    /// The routine step a `routineDone` log was for, if any.
    public let routineStepID: UUID?

    public init(
        id: UUID = UUID(),
        childID: UUID?,
        type: LogType,
        value: LogValue? = nil,
        note: String? = nil,
        timestamp: Date,
        loggedBy: String = "",
        source: EntrySource = .app,
        bodyAreas: [BodyArea] = [],
        routineStepID: UUID? = nil
    ) {
        self.id = id
        self.childID = childID
        self.type = type
        self.value = value
        self.note = note
        self.timestamp = timestamp
        self.loggedBy = loggedBy
        self.source = source
        self.bodyAreas = bodyAreas
        self.routineStepID = routineStepID
    }
}

/// A read-only copy of a child.
public struct ChildInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let birthDate: Date?
    public let colorTag: String
    public let isActive: Bool

    public init(id: UUID, name: String, birthDate: Date?, colorTag: String, isActive: Bool) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.colorTag = colorTag
        self.isActive = isActive
    }
}

extension LogEntry {
    /// Nil for rows with an unknown type or source (written by a newer app version).
    init?(_ event: LogEvent) {
        guard let type = event.type, let source = event.entrySource else { return nil }
        self.init(
            id: event.id,
            childID: event.child?.id,
            type: type,
            value: event.value,
            note: event.note,
            timestamp: event.timestamp,
            loggedBy: event.loggedBy,
            source: source,
            bodyAreas: event.bodyAreas,
            routineStepID: event.routineStepID
        )
    }
}

extension ChildInfo {
    init(_ child: Child) {
        self.init(
            id: child.id,
            name: child.name,
            birthDate: child.birthDate,
            colorTag: child.colorTag,
            isActive: child.isActive
        )
    }
}

/// A read-only copy of a routine step.
public struct RoutineStepInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let childID: UUID
    public let name: String
    public let time: RoutineTime
    public let order: Int
    public let isActive: Bool

    public init(id: UUID, childID: UUID, name: String, time: RoutineTime, order: Int, isActive: Bool) {
        self.id = id
        self.childID = childID
        self.name = name
        self.time = time
        self.order = order
        self.isActive = isActive
    }
}

extension RoutineStepInfo {
    /// Nil for a step with an unknown time (written by a newer app version).
    init?(_ step: RoutineStep) {
        guard let time = step.time else { return nil }
        self.init(id: step.id, childID: step.childID, name: step.name, time: time, order: step.order, isActive: step.isActive)
    }
}

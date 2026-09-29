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

/// A care plan, copied out of SwiftData.
public struct CarePlanInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let childID: UUID
    public let provider: String
    public let planDate: Date?
    public let sourceFileName: String?
    public let status: CarePlanStatus
    public let startedAt: Date?
    public let endedAt: Date?
}

extension CarePlanInfo {
    init?(_ plan: CarePlan) {
        guard let status = plan.status else { return nil }
        self.init(id: plan.id, childID: plan.childID, provider: plan.provider, planDate: plan.planDate,
                  sourceFileName: plan.sourceFileName, status: status, startedAt: plan.startedAt, endedAt: plan.endedAt)
    }
}

/// One plan item, copied out of SwiftData.
public struct PlanItemInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let planID: UUID
    public let kind: PlanItemKind
    public let text: String
    public let dose: String?
    public let frequency: String?
    public let timing: String?
    public let duration: String?
    public let sourcePage: Int?
    public let sourceLine: String?
    public let isConfirmed: Bool
    public let order: Int
}

extension PlanItemInfo {
    init?(_ item: PlanItem) {
        guard let kind = item.kind else { return nil }
        self.init(id: item.id, planID: item.planID, kind: kind, text: item.text, dose: item.dose,
                  frequency: item.frequency, timing: item.timing, duration: item.duration,
                  sourcePage: item.sourcePage, sourceLine: item.sourceLine, isConfirmed: item.isConfirmed, order: item.order)
    }
}

/// A provider visit, copied out of SwiftData.
public struct VisitInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let childID: UUID
    public let date: Date
    public let provider: String
    public let notes: String?
}

extension VisitInfo {
    init(_ visit: Visit) {
        self.init(id: visit.id, childID: visit.childID, date: visit.date, provider: visit.provider, notes: visit.notes)
    }
}

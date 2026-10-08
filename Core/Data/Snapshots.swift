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
    /// Set when a started care plan made this step.
    public let planItemID: UUID?
    /// Short, verb-first wording for the screen, when set.
    public let label: String?
    public let detail: String?
    /// The step's original wording, full length.
    public let sourceText: String?
    public let category: StepCategory?
    public let timesPerDay: Int?
    public let kind: StepKind
    /// When the step was made (a plan's steps: when the plan started).
    public let createdAt: Date?
    /// Its last change, such as being paused.
    public let updatedAt: Date?

    public init(id: UUID, childID: UUID, name: String, time: RoutineTime, order: Int, isActive: Bool, planItemID: UUID? = nil,
                label: String? = nil, detail: String? = nil, sourceText: String? = nil, category: StepCategory? = nil,
                timesPerDay: Int? = nil, kind: StepKind = .task, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.id = id
        self.childID = childID
        self.name = name
        self.time = time
        self.order = order
        self.isActive = isActive
        self.planItemID = planItemID
        self.label = label
        self.detail = detail
        self.sourceText = sourceText
        self.category = category
        self.timesPerDay = timesPerDay
        self.kind = kind
    }

    /// What the row says: the label, or the original wording without "Step 1:".
    public var displayName: String { label ?? StepLabeler.clean(sourceText ?? name) }
    /// The full original wording, for "From your plan".
    public var original: String { sourceText ?? name }
}

extension RoutineStepInfo {
    /// Nil for a step with an unknown time (written by a newer app version).
    init?(_ step: RoutineStep) {
        guard let time = step.time else { return nil }
        self.init(id: step.id, childID: step.childID, name: step.name, time: time, order: step.order,
                  isActive: step.isActive, planItemID: step.planItemID, label: step.label, detail: step.detail,
                  sourceText: step.sourceText, category: step.categoryRaw.flatMap(StepCategory.init),
                  timesPerDay: step.timesPerDay, kind: step.kindRaw.flatMap(StepKind.init) ?? .task,
                  createdAt: step.createdAt, updatedAt: step.updatedAt)
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
    /// How long the plan runs, in weeks, when the parent set it.
    public let lengthWeeks: Int?

    public init(id: UUID, childID: UUID, provider: String, planDate: Date?, sourceFileName: String?,
                status: CarePlanStatus, startedAt: Date?, endedAt: Date?, lengthWeeks: Int? = nil) {
        self.lengthWeeks = lengthWeeks
        self.id = id
        self.childID = childID
        self.provider = provider
        self.planDate = planDate
        self.sourceFileName = sourceFileName
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

extension CarePlanInfo {
    init?(_ plan: CarePlan) {
        guard let status = plan.status else { return nil }
        self.init(id: plan.id, childID: plan.childID, provider: plan.provider, planDate: plan.planDate,
                  sourceFileName: plan.sourceFileName, status: status, startedAt: plan.startedAt, endedAt: plan.endedAt,
                  lengthWeeks: plan.lengthWeeks)
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
    public let label: String?
    public let detail: String?
    public let category: StepCategory?
    /// Set on items split out of a list ("Continue A, B").
    public let parentItemID: UUID?
    /// Supplements: giving now (nil until the parent answers).
    public let isGiving: Bool?
    /// Supplements: the blocks it's given in; nil means the plan's default.
    public let givingTimes: [TodoBlock]?
    /// The provider's words in plain language, when checked and kept.
    public let plainText: String?
    /// The provider's whole paragraph, restored from the saved original.
    public let sourceParagraph: String?
    /// Supplements: the parent's dose steps, oldest first.
    public let doseSteps: [DoseStep]

    public init(id: UUID, planID: UUID, kind: PlanItemKind, text: String, dose: String?, frequency: String?,
                timing: String?, duration: String?, sourcePage: Int?, sourceLine: String?, isConfirmed: Bool, order: Int,
                label: String? = nil, detail: String? = nil, category: StepCategory? = nil, parentItemID: UUID? = nil,
                isGiving: Bool? = nil, givingTimes: [TodoBlock]? = nil, plainText: String? = nil,
                sourceParagraph: String? = nil, doseSteps: [DoseStep] = []) {
        self.doseSteps = doseSteps.sorted { $0.startDate < $1.startDate }
        self.isGiving = isGiving
        self.givingTimes = givingTimes
        self.plainText = plainText
        self.sourceParagraph = sourceParagraph
        self.label = label
        self.detail = detail
        self.category = category
        self.parentItemID = parentItemID
        self.id = id
        self.planID = planID
        self.kind = kind
        self.text = text
        self.dose = dose
        self.frequency = frequency
        self.timing = timing
        self.duration = duration
        self.sourcePage = sourcePage
        self.sourceLine = sourceLine
        self.isConfirmed = isConfirmed
        self.order = order
    }
}

extension PlanItemInfo {
    /// The provider's exact words, never cut: the whole paragraph when it was
    /// restored, else the quoted line, else the item's text.
    public var providerWords: String { sourceParagraph ?? sourceLine ?? text }

    /// The amount for a day: the latest dose step that has started, else the plan's dose.
    public func dose(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> String? {
        let end = calendar.startOfDay(for: date).addingTimeInterval(86_400)
        return doseSteps.last { $0.startDate < end }?.amount ?? dose
    }

    /// When a supplement is given: the parent's choice, or the plan's default.
    public var blocks: [TodoBlock] { givingTimes ?? TodoBlock.defaults(forFrequency: frequency) }
}

extension PlanItemInfo {
    init?(_ item: PlanItem) {
        guard let kind = item.kind else { return nil }
        self.init(id: item.id, planID: item.planID, kind: kind, text: item.text, dose: item.dose,
                  frequency: item.frequency, timing: item.timing, duration: item.duration,
                  sourcePage: item.sourcePage, sourceLine: item.sourceLine, isConfirmed: item.isConfirmed, order: item.order,
                  label: item.label, detail: item.detail, category: item.categoryRaw.flatMap(StepCategory.init),
                  parentItemID: item.parentItemID, isGiving: item.isGiving,
                  givingTimes: TodoBlock.parse(item.givingTimesRaw), plainText: item.plainText,
                  sourceParagraph: item.sourceParagraph, doseSteps: DoseStep.decode(item.doseStepsRaw))
    }
}

/// A provider visit, copied out of SwiftData.
public struct VisitInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let childID: UUID
    public let date: Date
    public let provider: String
    public let notes: String?

    public init(id: UUID, childID: UUID, date: Date, provider: String, notes: String?) {
        self.id = id
        self.childID = childID
        self.date = date
        self.provider = provider
        self.notes = notes
    }
}

extension VisitInfo {
    init(_ visit: Visit) {
        self.init(id: visit.id, childID: visit.childID, date: visit.date, provider: visit.provider, notes: visit.notes)
    }
}

/// One dose step the parent set: from this day on, give this amount.
public struct DoseStep: Codable, Hashable, Sendable {
    public var amount: String
    public var startDate: Date

    public init(amount: String, startDate: Date) {
        self.amount = amount
        self.startDate = startDate
    }

    static func decode(_ raw: String?) -> [DoseStep] {
        guard let data = raw?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder.doseSteps.decode([DoseStep].self, from: data)) ?? []
    }

    static func encode(_ steps: [DoseStep]) -> String? {
        guard !steps.isEmpty, let data = try? JSONEncoder.doseSteps.encode(steps.sorted { $0.startDate < $1.startDate })
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension JSONEncoder {
    static var doseSteps: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var doseSteps: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

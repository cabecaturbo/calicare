import Foundation

/// Plan tab: which of the plan's steps the family uses. A step is in use when
/// it shows in To do: a routine or skin step with an active task step, or a
/// supplement they're giving. Everything else in the plan is for reading.
public struct PlanUse: Equatable, Sendable {
    public enum Group: String, CaseIterable, Sendable {
        case skin, routine, supplements

        public var title: String {
            switch self {
            case .skin: "Skin care"
            case .routine: "Routine"
            case .supplements: "Supplements"
            }
        }
    }

    /// One plan step that can go in To do.
    public struct Row: Identifiable, Equatable, Sendable {
        public let item: PlanItemInfo
        public let group: Group
        /// "Apply aloe vera", "Brand D Drops".
        public let name: String
        /// What it is, in the plan's words: "96% or more pure. Plant Therapy
        /// or Amara Beauty brands." Nil when the plan says nothing more.
        public let detail: String?
        /// Beside the name: "AM · PM" for a step, the dose for a supplement.
        public let meta: String?
        public let isInUse: Bool
        /// The To do steps this row turns on and off (empty for supplements).
        public let stepIDs: [UUID]

        public var id: UUID { item.id }
    }

    /// What a tap changes.
    public enum Change: Equatable, Sendable {
        case steps([UUID], active: Bool)
        case giving(UUID, Bool)
    }

    public let rows: [Row]
    /// Plan items that never go in To do: baths, food, basics, follow-ups,
    /// supplement rules and mentions.
    public let reference: [PlanItemInfo]

    public init(items: [PlanItemInfo], steps: [RoutineStepInfo]) {
        let parents = Set(items.compactMap(\.parentItemID))
        var rows: [Row] = []
        var reference: [PlanItemInfo] = []
        for item in items.sorted(by: { $0.order < $1.order }) where !parents.contains(item.id) {
            switch item.kind {
            case .routineStep, .topicalStep:
                let tasks = steps.filter { $0.planItemID == item.id && $0.kind == .task }
                guard let first = tasks.first else {
                    reference.append(item)
                    continue
                }
                rows.append(Row(
                    item: item,
                    group: item.kind == .topicalStep || first.category == .apply ? .skin : .routine,
                    name: first.displayName,
                    detail: Self.detail(first.detail),
                    meta: Self.when(Set(tasks.map(\.time))),
                    isInUse: tasks.contains(where: \.isActive),
                    stepIDs: tasks.map(\.id)
                ))
            case .supplement where SupplementPlan.isProduct(item):
                let display = SupplementDisplay(item)
                rows.append(Row(item: item, group: .supplements, name: display.name,
                                detail: Self.detail(Self.sentences(display.howToGive)), meta: item.dose,
                                isInUse: item.isGiving == true, stepIDs: []))
            default:
                reference.append(item)
            }
        }
        self.rows = rows
        self.reference = reference
    }

    public var inUse: Int { rows.filter(\.isInUse).count }
    public var total: Int { rows.count }

    /// "8 of 9 steps are in To do." / "All 4 steps are in To do." / "None of the 9 steps are in To do yet."
    public var line: String {
        switch inUse {
        case 0: return total == 1 ? "The 1 step isn't in To do yet." : "None of the \(total) steps are in To do yet."
        case total: return total == 1 ? "The 1 step is in To do." : "All \(total) steps are in To do."
        default: return "\(inUse) of \(total) steps are in To do."
        }
    }

    public func rows(in group: Group) -> [Row] { rows.filter { $0.group == group } }

    /// Turning a row on or off.
    public static func change(_ row: Row, to isOn: Bool) -> Change {
        row.group == .supplements ? .giving(row.item.id, isOn) : .steps(row.stepIDs, active: isOn)
    }

    /// "Use all" or "Use none": only the rows that would change (in one group, or all).
    public func changeAll(to isOn: Bool, in group: Group? = nil) -> [Change] {
        rows.filter { $0.isInUse != isOn && (group == nil || $0.group == group) }.map { Self.change($0, to: isOn) }
    }

    /// The plan's extra words, starting with a capital: "if tolerated. If…" → "If tolerated. If…".
    public static func detail(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "Mix into water." + "Can take long-term" → "Mix into water. Can take long-term."
    static func sentences(_ parts: [String]) -> String {
        parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }
            .joined(separator: " ")
    }

    private static func when(_ times: Set<RoutineTime>) -> String {
        switch (times.contains(.morning), times.contains(.evening)) {
        case (true, true): "AM · PM"
        case (true, false): "AM"
        default: "PM"
        }
    }
}

/// Saves a Plan tab change through the stores To do already reads.
public struct PlanUseActions: Sendable {
    private let routine: RoutineStore
    private let plans: CarePlanStore

    public init(routine: RoutineStore, plans: CarePlanStore) {
        self.routine = routine
        self.plans = plans
    }

    public func apply(_ changes: [PlanUse.Change]) async throws {
        for change in changes {
            switch change {
            case .steps(let ids, let active):
                for id in ids { try await routine.setActive(id, active) }
            case .giving(let id, let isGiving):
                try await plans.setGiving(id, isGiving)
            }
        }
    }
}

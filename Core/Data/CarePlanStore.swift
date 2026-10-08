import Foundation
import SwiftData

public enum CarePlanStoreError: Error, Equatable, Sendable {
    case planNotFound, itemNotFound, childNotFound
    /// Every item needs its words.
    case emptyText
    /// Only a draft can be edited or started.
    case notDraft
    /// "Start this plan" needs at least one confirmed item.
    case nothingConfirmed
}

/// One item as read from the provider's plan, before it's saved.
public struct PlanItemDraft: Equatable, Sendable {
    public var kind: PlanItemKind
    public var text: String
    public var dose: String?
    public var frequency: String?
    public var timing: String?
    public var duration: String?
    public var sourcePage: Int?
    public var sourceLine: String?
    /// Proposed by the plan reader; kept only if it follows StepLabeler's rules.
    public var label: String?
    public var detail: String?
    public var category: StepCategory?
    /// Plain words from the plan reader; kept only if `PlainWords.isFaithful`.
    public var plain: String?

    public init(kind: PlanItemKind, text: String, dose: String? = nil, frequency: String? = nil, timing: String? = nil,
                duration: String? = nil, sourcePage: Int? = nil, sourceLine: String? = nil, label: String? = nil,
                detail: String? = nil, category: StepCategory? = nil, plain: String? = nil) {
        self.plain = plain
        self.label = label
        self.detail = detail
        self.category = category
        self.kind = kind
        self.text = text
        self.dose = dose
        self.frequency = frequency
        self.timing = timing
        self.duration = duration
        self.sourcePage = sourcePage
        self.sourceLine = sourceLine
    }
}

/// Care plans, their items, and provider visits for each child.
/// A plan is a draft until the parent confirms items and starts it; starting
/// keeps only the confirmed items and ends the child's previous plan.
public actor CarePlanStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let now: @Sendable () -> Date

    public init(modelContainer: ModelContainer, now: @escaping @Sendable () -> Date = { .now }) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.now = now
    }

    // MARK: - Plans

    /// A new draft with its items in order. Nothing is live yet.
    @discardableResult
    public func createDraft(child childID: UUID, provider: String, planDate: Date? = nil,
                            sourceFileName: String? = nil, items: [PlanItemDraft]) async throws -> CarePlanInfo {
        let children = FetchDescriptor<Child>(predicate: #Predicate { $0.id == childID && $0.deletedAt == nil })
        guard try modelContext.fetchCount(children) > 0 else { throw CarePlanStoreError.childNotFound }
        let current = now()
        let plan = CarePlan(childID: childID, provider: Self.clean(provider) ?? "", planDate: planDate,
                            sourceFileName: sourceFileName, now: current)
        modelContext.insert(plan)
        for (index, draft) in items.enumerated() {
            guard let text = Self.clean(draft.text) else { throw CarePlanStoreError.emptyText }
            let item = PlanItem(
                planID: plan.id, childID: childID, kind: draft.kind, text: text,
                dose: Self.clean(draft.dose), frequency: Self.clean(draft.frequency), timing: Self.clean(draft.timing),
                duration: Self.clean(draft.duration), sourcePage: draft.sourcePage, sourceLine: Self.clean(draft.sourceLine),
                order: index, now: current
            )
            // A proposed label stays only if it's made of the plan's own words.
            if let label = Self.clean(draft.label),
               StepLabeler.isValid(label: label, detail: Self.clean(draft.detail), source: item.sourceLine ?? text) {
                item.label = label
                item.detail = Self.clean(draft.detail)
            }
            item.categoryRaw = draft.category?.rawValue
            if let plain = Self.clean(draft.plain), PlainWords.isFaithful(plain, to: item.sourceLine ?? text) {
                item.plainText = plain
            }
            modelContext.insert(item)
        }
        try modelContext.save()
        guard let info = CarePlanInfo(plan) else { throw CarePlanStoreError.planNotFound }
        return info
    }

    /// A child's plans, newest first.
    public func plans(child childID: UUID) async throws -> [CarePlanInfo] {
        let descriptor = FetchDescriptor<CarePlan>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).compactMap(CarePlanInfo.init)
    }

    public func activePlan(child childID: UUID) async throws -> CarePlanInfo? {
        try await plans(child: childID).first { $0.status == .active }
    }

    /// Starts a draft: unconfirmed items are dropped, the previous active plan ends.
    @discardableResult
    public func start(_ planID: UUID) async throws -> CarePlanInfo {
        let plan = try fetchPlan(planID)
        guard plan.status == .draft else { throw CarePlanStoreError.notDraft }
        let items = try fetchItems(planID)
        guard items.contains(where: \.isConfirmed) else { throw CarePlanStoreError.nothingConfirmed }
        let current = now()
        for item in items where !item.isConfirmed {
            touch(item, at: current)
            item.deletedAt = current
        }
        let childID = plan.childID
        let active = CarePlanStatus.active.rawValue
        let others = try modelContext.fetch(FetchDescriptor<CarePlan>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil && $0.statusRaw == active }
        ))
        for other in others where other.id != planID {
            other.statusRaw = CarePlanStatus.ended.rawValue
            other.endedAt = current
            touch(other, at: current)
        }
        for other in others where other.id != planID {
            try removeRoutineSteps(of: other.id, at: current)
        }
        plan.statusRaw = active
        plan.startedAt = current
        touch(plan, at: current)
        try addRoutineSteps(for: items.filter(\.isConfirmed), child: plan.childID, at: current)
        try modelContext.save()
        // Full wording, labels, and split lists for the new steps and items.
        try StepBackfill.run(in: modelContext, now: current)
        guard let info = CarePlanInfo(plan) else { throw CarePlanStoreError.planNotFound }
        return info
    }

    /// A clean slate for one child: every plan and plan item, and every
    /// routine step, is removed (soft delete, so it syncs). Logs, foods,
    /// products, and photos stay. Returns how many rows were removed.
    @discardableResult
    public func removeAllPlansAndSteps(child childID: UUID) async throws -> Int {
        let current = now()
        var count = 0
        for plan in try modelContext.fetch(FetchDescriptor<CarePlan>(predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil })) {
            plan.deletedAt = current
            touch(plan, at: current)
            count += 1
        }
        for item in try modelContext.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil })) {
            item.deletedAt = current
            touch(item, at: current)
            count += 1
        }
        for step in try modelContext.fetch(FetchDescriptor<RoutineStep>(predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil })) {
            step.deletedAt = current
            step.updatedAt = current
            step.needsSync = true
            count += 1
        }
        try modelContext.save()
        return count
    }

    // MARK: - Supplements and wording (To do + Info)

    /// Whether the parent is giving a supplement now. Works on started plans.
    public func setGiving(_ itemID: UUID, _ isGiving: Bool) async throws {
        try changeItem(itemID) { $0.isGiving = isGiving }
    }

    /// The parent's dose steps for a supplement. An empty list clears them.
    public func setDoseSteps(_ itemID: UUID, _ steps: [DoseStep]) async throws {
        try changeItem(itemID) { $0.doseStepsRaw = DoseStep.encode(steps) }
    }

    /// How long the plan runs, in weeks; nil when the parent clears it.
    public func setLength(_ planID: UUID, weeks: Int?) async throws {
        let plan = try fetchPlan(planID)
        plan.lengthWeeks = weeks.map { min(max($0, 1), 104) }
        touch(plan, at: now())
        try modelContext.save()
    }

    /// When a supplement is given. An empty list keeps the plan's default.
    public func setGivingTimes(_ itemID: UUID, _ blocks: [TodoBlock]) async throws {
        try changeItem(itemID) { $0.givingTimesRaw = blocks.isEmpty ? nil : TodoBlock.raw(blocks) }
    }

    /// Plain words for an item, kept only if they pass `PlainWords.isFaithful`.
    @discardableResult
    public func setPlainText(_ itemID: UUID, _ plain: String) async throws -> Bool {
        var kept = false
        try changeItem(itemID) { item in
            let source = item.sourceParagraph ?? item.sourceLine ?? item.text
            guard PlainWords.isFaithful(plain, to: source) else { return }
            item.plainText = plain.trimmingCharacters(in: .whitespacesAndNewlines)
            kept = true
        }
        return kept
    }

    /// The provider's whole paragraph, when the quoted line was cut short.
    /// Only ever longer than, and starting with, what's there.
    public func setSourceParagraph(_ itemID: UUID, _ paragraph: String) async throws {
        try changeItem(itemID) { item in
            let line = item.sourceLine ?? item.text
            guard paragraph.count > line.count, PlainWords.normalize(paragraph).hasPrefix(PlainWords.normalize(line)) else { return }
            item.sourceParagraph = paragraph
        }
    }

    /// Undoes `removeAllPlansAndSteps` for the parent's own steps (no plan
    /// link): the ones removed at the same moment as a plan. Same ids, so
    /// their history comes back too. Returns how many came back.
    @discardableResult
    public func restoreOwnSteps(child childID: UUID) async throws -> Int {
        let removedPlans = Set(try modelContext.fetch(FetchDescriptor<CarePlan>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt != nil }
        )).compactMap(\.deletedAt))
        guard !removedPlans.isEmpty else { return 0 }
        let steps = try modelContext.fetch(FetchDescriptor<RoutineStep>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt != nil && $0.planItemID == nil }
        ))
        let current = now()
        var count = 0
        for step in steps where step.deletedAt.map(removedPlans.contains) == true {
            step.deletedAt = nil
            step.updatedAt = current
            step.needsSync = true
            count += 1
        }
        try modelContext.save()
        return count
    }

    private func changeItem(_ itemID: UUID, _ edit: (PlanItem) -> Void) throws {
        var descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == itemID && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        guard let item = try modelContext.fetch(descriptor).first else { throw CarePlanStoreError.itemNotFound }
        edit(item)
        if item.hasChanges { touch(item, at: now()) }
        try modelContext.save()
    }

    public func end(_ planID: UUID) async throws {
        let plan = try fetchPlan(planID)
        let current = now()
        try removeRoutineSteps(of: planID, at: current)
        plan.statusRaw = CarePlanStatus.ended.rawValue
        plan.endedAt = current
        touch(plan, at: current)
        try modelContext.save()
    }

    /// Soft-deletes a plan and its items (a draft the parent didn't want).
    public func delete(_ planID: UUID) async throws {
        let plan = try fetchPlan(planID)
        let current = now()
        for item in try fetchItems(planID) {
            item.deletedAt = current
            touch(item, at: current)
        }
        plan.deletedAt = current
        touch(plan, at: current)
        try modelContext.save()
    }

    // MARK: - Items

    public func items(plan planID: UUID) async throws -> [PlanItemInfo] {
        try fetchItems(planID).compactMap(PlanItemInfo.init)
    }

    /// Changes an item on a draft. The source page and line never change.
    public func update(_ itemID: UUID, with draft: PlanItemDraft) async throws {
        let item = try fetchDraftItem(itemID)
        guard let text = Self.clean(draft.text) else { throw CarePlanStoreError.emptyText }
        item.kindRaw = draft.kind.rawValue
        item.text = text
        item.dose = Self.clean(draft.dose)
        item.frequency = Self.clean(draft.frequency)
        item.timing = Self.clean(draft.timing)
        item.duration = Self.clean(draft.duration)
        touch(item, at: now())
        try modelContext.save()
    }

    public func setConfirmed(_ itemID: UUID, _ isConfirmed: Bool) async throws {
        let item = try fetchDraftItem(itemID)
        item.isConfirmed = isConfirmed
        touch(item, at: now())
        try modelContext.save()
    }

    public func remove(_ itemID: UUID) async throws {
        let item = try fetchDraftItem(itemID)
        let current = now()
        item.deletedAt = current
        touch(item, at: current)
        try modelContext.save()
    }

    // MARK: - Visits

    @discardableResult
    public func addVisit(child childID: UUID, date: Date, provider: String, notes: String? = nil) async throws -> VisitInfo {
        let visit = Visit(childID: childID, date: date, provider: Self.clean(provider) ?? "", notes: Self.clean(notes), now: now())
        modelContext.insert(visit)
        try modelContext.save()
        return VisitInfo(visit)
    }

    /// A child's visits, newest first.
    public func visits(child childID: UUID) async throws -> [VisitInfo] {
        let descriptor = FetchDescriptor<Visit>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(VisitInfo.init)
    }

    /// The most recent visit that has happened, for "Since visit".
    public func lastVisit(child childID: UUID) async throws -> VisitInfo? {
        let current = now()
        return try await visits(child: childID).first { $0.date <= current }
    }

    public func deleteVisit(_ id: UUID) async throws {
        var descriptor = FetchDescriptor<Visit>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        guard let visit = try modelContext.fetch(descriptor).first else { return }
        let current = now()
        visit.deletedAt = current
        touch(visit, at: current)
        try modelContext.save()
    }

    // MARK: - Routine steps from the plan

    /// A plan item's step at more times (Plan › an item › a time switched on
    /// that has no step yet). Adds rows only; existing steps are untouched.
    public func addSteps(for itemID: UUID, times: [RoutineTime]) async throws {
        guard let item = try modelContext.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == itemID })).first
        else { throw CarePlanStoreError.itemNotFound }
        let planID = item.planID
        guard let plan = try modelContext.fetch(FetchDescriptor<CarePlan>(predicate: #Predicate { $0.id == planID })).first
        else { throw CarePlanStoreError.planNotFound }
        let childID = plan.childID
        let steps = try modelContext.fetch(FetchDescriptor<RoutineStep>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil }
        ))
        let mine = steps.filter { $0.planItemID == itemID }
        let template = mine.first
        let current = now()
        for time in times where !mine.contains(where: { $0.timeRaw == time.rawValue }) {
            let order = (steps.filter { $0.timeRaw == time.rawValue }.map(\.order).max() ?? -1) + 1
            let step = RoutineStep(childID: childID, name: template?.name ?? String(item.text.prefix(80)), time: time,
                                   order: order, planItemID: itemID, now: current)
            step.label = template?.label
            step.detail = template?.detail
            step.sourceText = template?.sourceText
            step.categoryRaw = template?.categoryRaw
            step.kindRaw = template?.kindRaw
            step.timesPerDay = template?.timesPerDay
            modelContext.insert(step)
        }
        try modelContext.save()
    }

    /// The plan's daily steps join Plan's routine, after the parent's own, in
    /// the plan's order: morning, evening, or both (see PlanRoutine).
    private func addRoutineSteps(for items: [PlanItem], child childID: UUID, at date: Date) throws {
        let existing = try modelContext.fetch(FetchDescriptor<RoutineStep>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil }
        ))
        var next: [RoutineTime: Int] = [:]
        for time in RoutineTime.allCases {
            next[time] = (existing.filter { $0.timeRaw == time.rawValue }.map(\.order).max() ?? -1) + 1
        }
        for item in items {
            guard let kind = item.kind, PlanRoutine.isDailyStep(kind: kind, text: item.text) else { continue }
            for time in PlanRoutine.times(text: item.text, timing: item.timing, frequency: item.frequency) {
                modelContext.insert(RoutineStep(
                    childID: childID, name: String(item.text.prefix(80)), time: time,
                    order: next[time] ?? 0, planItemID: item.id, now: date
                ))
                next[time, default: 0] += 1
            }
        }
    }

    /// A plan that ends takes its steps out of Plan (soft delete; history stays).
    private func removeRoutineSteps(of planID: UUID, at date: Date) throws {
        let itemIDs = try modelContext.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.planID == planID })).map(\.id)
        guard !itemIDs.isEmpty else { return }
        let steps = try modelContext.fetch(FetchDescriptor<RoutineStep>(
            predicate: #Predicate { $0.deletedAt == nil }
        )).filter { $0.planItemID.map(itemIDs.contains) ?? false }
        for step in steps {
            step.deletedAt = date
            step.updatedAt = date
            step.needsSync = true
        }
    }

    // MARK: - Helpers

    private func fetchPlan(_ id: UUID) throws -> CarePlan {
        var descriptor = FetchDescriptor<CarePlan>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        guard let plan = try modelContext.fetch(descriptor).first else { throw CarePlanStoreError.planNotFound }
        return plan
    }

    private func fetchItems(_ planID: UUID) throws -> [PlanItem] {
        try modelContext.fetch(FetchDescriptor<PlanItem>(
            predicate: #Predicate { $0.planID == planID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.order)]
        ))
    }

    private func fetchDraftItem(_ id: UUID) throws -> PlanItem {
        var descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        guard let item = try modelContext.fetch(descriptor).first else { throw CarePlanStoreError.itemNotFound }
        guard try fetchPlan(item.planID).status == .draft else { throw CarePlanStoreError.notDraft }
        return item
    }

    private func touch(_ plan: CarePlan, at date: Date) {
        plan.updatedAt = date
        plan.needsSync = true
    }

    private func touch(_ item: PlanItem, at date: Date) {
        item.updatedAt = date
        item.needsSync = true
    }

    private func touch(_ visit: Visit, at date: Date) {
        visit.updatedAt = date
        visit.needsSync = true
    }

    /// Trimmed, or nil when empty.
    private static func clean(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

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

    public init(kind: PlanItemKind, text: String, dose: String? = nil, frequency: String? = nil, timing: String? = nil,
                duration: String? = nil, sourcePage: Int? = nil, sourceLine: String? = nil) {
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
            modelContext.insert(PlanItem(
                planID: plan.id, childID: childID, kind: draft.kind, text: text,
                dose: Self.clean(draft.dose), frequency: Self.clean(draft.frequency), timing: Self.clean(draft.timing),
                duration: Self.clean(draft.duration), sourcePage: draft.sourcePage, sourceLine: Self.clean(draft.sourceLine),
                order: index, now: current
            ))
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
        plan.statusRaw = active
        plan.startedAt = current
        touch(plan, at: current)
        try modelContext.save()
        guard let info = CarePlanInfo(plan) else { throw CarePlanStoreError.planNotFound }
        return info
    }

    public func end(_ planID: UUID) async throws {
        let plan = try fetchPlan(planID)
        let current = now()
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

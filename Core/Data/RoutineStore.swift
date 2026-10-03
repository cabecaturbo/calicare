import Foundation
import SwiftData

public enum RoutineStoreError: Error, Equatable, Sendable {
    /// A step needs a name.
    case emptyName
    case childNotFound
    case stepNotFound
}

/// A child's routine steps, morning and evening, in the order the parent set.
/// Ticking one off goes through `LogStore.logRoutineStep`.
public actor RoutineStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let now: @Sendable () -> Date

    public init(modelContainer: ModelContainer, now: @escaping @Sendable () -> Date = { .now }) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.now = now
    }

    /// Live steps for one child, in order. `time` narrows to morning or evening;
    /// inactive steps are left out unless `includeInactive`.
    public func steps(child childID: UUID, time: RoutineTime? = nil, includeInactive: Bool = false) async throws -> [RoutineStepInfo] {
        try fetchSteps(child: childID)
            .compactMap(RoutineStepInfo.init)
            .filter { (time == nil || $0.time == time) && (includeInactive || $0.isActive) }
    }

    /// Adds a step at the end of its morning or evening list.
    @discardableResult
    public func add(name: String, time: RoutineTime, child childID: UUID) async throws -> RoutineStepInfo {
        let trimmed = try Self.clean(name)
        let children = FetchDescriptor<Child>(predicate: #Predicate { $0.id == childID && $0.deletedAt == nil })
        guard try modelContext.fetchCount(children) > 0 else { throw RoutineStoreError.childNotFound }
        let raw = time.rawValue
        let last = try fetchSteps(child: childID).filter { $0.timeRaw == raw }.map(\.order).max() ?? -1
        let step = RoutineStep(childID: childID, name: trimmed, time: time, order: last + 1, now: now())
        let full = name.trimmingCharacters(in: .whitespacesAndNewlines)
        step.sourceText = full
        StepBackfill.apply(StepLabeler.wording(for: full), to: step)
        modelContext.insert(step)
        try modelContext.save()
        guard let info = RoutineStepInfo(step) else { throw RoutineStoreError.stepNotFound }
        return info
    }

    /// Renaming changes what the screen shows (the label). The step's original
    /// words (`sourceText`) and its saved name never change.
    public func rename(_ id: UUID, to name: String) async throws {
        let trimmed = try Self.clean(name)
        try change(id) { $0.label = trimmed }
    }

    /// Paused steps keep their place and history but aren't shown as today's steps.
    public func setActive(_ id: UUID, _ isActive: Bool) async throws {
        try change(id) { $0.isActive = isActive }
    }

    /// Puts one morning or evening list in the given order. Steps not listed keep
    /// their relative order after the listed ones.
    public func reorder(child childID: UUID, time: RoutineTime, ids: [UUID]) async throws {
        let raw = time.rawValue
        let steps = try fetchSteps(child: childID).filter { $0.timeRaw == raw }
        let listed = ids.compactMap { id in steps.first { $0.id == id } }
        let rest = steps.filter { !ids.contains($0.id) }
        let current = now()
        for (index, step) in (listed + rest).enumerated() where step.order != index {
            step.order = index
            step.updatedAt = current
            step.needsSync = true
        }
        try modelContext.save()
    }

    /// Soft delete. Logs that ticked it off stay.
    public func delete(_ id: UUID) async throws {
        let current = now()
        try change(id) { $0.deletedAt = current }
    }

    private func change(_ id: UUID, _ edit: (RoutineStep) -> Void) throws {
        var descriptor = FetchDescriptor<RoutineStep>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        guard let step = try modelContext.fetch(descriptor).first else { throw RoutineStoreError.stepNotFound }
        edit(step)
        step.updatedAt = now()
        step.needsSync = true
        try modelContext.save()
    }

    private func fetchSteps(child childID: UUID) throws -> [RoutineStep] {
        let descriptor = FetchDescriptor<RoutineStep>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    private static func clean(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RoutineStoreError.emptyName }
        return String(trimmed.prefix(80))
    }
}

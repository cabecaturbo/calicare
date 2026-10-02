import Foundation
import SwiftData

public enum FoodStoreError: Error, Equatable, Sendable {
    case emptyName, duplicate, notFound
}

/// A child's food list: safe, testing, and paused foods, each with who decided.
public actor FoodStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let now: @Sendable () -> Date

    public init(modelContainer: ModelContainer, now: @escaping @Sendable () -> Date = { .now }) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.now = now
    }

    /// A child's foods, by name.
    public func foods(child childID: UUID) async throws -> [FoodInfo] {
        try fetch(child: childID).compactMap(FoodInfo.init)
    }

    /// Adds a food. The family comes from the built-in table unless given.
    @discardableResult
    public func add(name: String, status: FoodStatus, decidedBy: FoodDecider, family: String? = nil,
                    child childID: UUID) async throws -> FoodInfo {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw FoodStoreError.emptyName }
        guard try !fetch(child: childID).contains(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) else {
            throw FoodStoreError.duplicate
        }
        let food = Food(childID: childID, name: String(clean.prefix(80)), family: family ?? FoodFamilies.family(for: clean),
                        status: status, decidedBy: decidedBy, now: now())
        modelContext.insert(food)
        try modelContext.save()
        guard let info = FoodInfo(food) else { throw FoodStoreError.notFound }
        return info
    }

    /// Moves a food to another status, noting when and who decided.
    public func setStatus(_ id: UUID, _ status: FoodStatus, decidedBy: FoodDecider) async throws {
        try change(id) { food, date in
            guard food.statusRaw != status.rawValue else { return }
            food.statusRaw = status.rawValue
            food.statusChangedAt = date
            food.decidedByRaw = decidedBy.rawValue
        }
    }

    public func setFamily(_ id: UUID, _ family: String?) async throws {
        try change(id) { food, _ in food.family = family?.isEmpty == true ? nil : family }
    }

    public func setNote(_ id: UUID, _ note: String?) async throws {
        try change(id) { food, _ in
            let clean = note?.trimmingCharacters(in: .whitespacesAndNewlines)
            food.note = clean?.isEmpty == false ? clean : nil
        }
    }

    public func delete(_ id: UUID) async throws {
        try change(id) { food, date in food.deletedAt = date }
    }

    private func change(_ id: UUID, _ edit: (Food, Date) -> Void) throws {
        var descriptor = FetchDescriptor<Food>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        guard let food = try modelContext.fetch(descriptor).first else { throw FoodStoreError.notFound }
        let date = now()
        edit(food, date)
        food.updatedAt = date
        food.needsSync = true
        try modelContext.save()
    }

    private func fetch(child childID: UUID) throws -> [Food] {
        try modelContext.fetch(FetchDescriptor<Food>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.name)]
        ))
    }
}

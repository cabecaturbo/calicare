import Foundation
import SwiftData

public enum ChildStoreError: Error, Equatable, Sendable {
    /// A child needs a name.
    case emptyName
}

/// Adds, lists, and removes children.
public actor ChildStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let now: @Sendable () -> Date

    public init(modelContainer: ModelContainer, now: @escaping @Sendable () -> Date = { .now }) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.now = now
    }

    /// Adds a child. The name is trimmed and can't be empty.
    @discardableResult
    public func addChild(name: String, birthDate: Date? = nil, colorTag: String) async throws -> ChildInfo {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChildStoreError.emptyName }
        let child = Child(name: trimmed, birthDate: birthDate, colorTag: colorTag, now: now())
        modelContext.insert(child)
        try modelContext.save()
        return ChildInfo(child)
    }

    /// Active, non-deleted children, oldest first.
    public func activeChildren() async throws -> [ChildInfo] {
        let descriptor = FetchDescriptor<Child>(
            predicate: #Predicate { $0.deletedAt == nil && $0.isActive },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor).map { ChildInfo($0) }
    }

    /// Soft delete. Their logs stay, for sync and history.
    public func deleteChild(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<Child>(predicate: #Predicate { $0.id == id })
        guard let child = try modelContext.fetch(descriptor).first else { return }
        let current = now()
        child.deletedAt = current
        child.updatedAt = current
        child.needsSync = true
        try modelContext.save()
    }

    /// The saved current child if still active, otherwise the first active child.
    public func currentChild(setting: CurrentChildSetting = CurrentChildSetting()) async throws -> ChildInfo? {
        let children = try await activeChildren()
        if let saved = setting.childID, let match = children.first(where: { $0.id == saved }) {
            return match
        }
        return children.first
    }
}

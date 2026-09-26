import AppIntents
import Foundation

/// A child Siri and Shortcuts can pick. Defaults to the current child.
public struct ChildEntity: AppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Child"
    public static let defaultQuery = ChildEntityQuery()

    public let id: UUID
    public let name: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(_ child: ChildInfo) {
        self.init(id: child.id, name: child.name)
    }
}

public struct ChildEntityQuery: EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [UUID]) async throws -> [ChildEntity] {
        try await Self.activeChildren().filter { identifiers.contains($0.id) }
    }

    public func entities(matching string: String) async throws -> [ChildEntity] {
        try await Self.activeChildren().filter { $0.name.localizedStandardContains(string) }
    }

    public func suggestedEntities() async throws -> [ChildEntity] {
        try await Self.activeChildren()
    }

    public func defaultResult() async -> ChildEntity? {
        guard let child = try? await Self.store().currentChild() else { return nil }
        return ChildEntity(child)
    }

    private static func store() throws -> ChildStore {
        ChildStore(modelContainer: try CaliCareModelContainer.shared())
    }

    private static func activeChildren() async throws -> [ChildEntity] {
        try await store().activeChildren().map(ChildEntity.init)
    }
}

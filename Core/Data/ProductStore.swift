import Foundation
import SwiftData

public enum ProductStoreError: Error, Equatable, Sendable {
    case emptyName, notFound
}

/// A child's product diary: what they use, since when, and the "never again" list.
public actor ProductStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor
    private let now: @Sendable () -> Date

    public init(modelContainer: ModelContainer, now: @escaping @Sendable () -> Date = { .now }) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.now = now
    }

    /// A child's products, by name.
    public func products(child childID: UUID) async throws -> [ProductInfo] {
        try modelContext.fetch(FetchDescriptor<Product>(
            predicate: #Predicate { $0.childID == childID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.name)]
        )).map(ProductInfo.init)
    }

    @discardableResult
    public func add(name: String, category: ProductCategory, startedAt: Date, child childID: UUID) async throws -> ProductInfo {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw ProductStoreError.emptyName }
        let product = Product(childID: childID, name: String(clean.prefix(80)), category: category,
                              startedAt: startedAt, now: now())
        modelContext.insert(product)
        try modelContext.save()
        return ProductInfo(product)
    }

    public func edit(_ id: UUID, name: String, category: ProductCategory, startedAt: Date) async throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw ProductStoreError.emptyName }
        try change(id) { product, _ in
            product.name = String(clean.prefix(80))
            product.categoryRaw = category.rawValue
            product.startedAt = startedAt
        }
    }

    /// Stopped using it, without ruling it out.
    public func stop(_ id: UUID, on date: Date) async throws {
        try change(id) { product, _ in product.stoppedAt = date }
    }

    /// "Never again", with the parent's reason. Stops it too, if still in use.
    public func neverAgain(_ id: UUID, reason: String?) async throws {
        try change(id) { product, date in
            product.neverAgain = true
            product.reason = Self.clean(reason)
            if product.stoppedAt == nil { product.stoppedAt = date }
        }
    }

    /// Back in use from `date`: clears stopped and "never again".
    public func resume(_ id: UUID, from date: Date) async throws {
        try change(id) { product, _ in
            product.stoppedAt = nil
            product.neverAgain = false
            product.reason = nil
            product.startedAt = date
        }
    }

    public func delete(_ id: UUID) async throws {
        try change(id) { product, date in product.deletedAt = date }
    }

    func change(_ id: UUID, _ edit: (Product, Date) -> Void) throws {
        var descriptor = FetchDescriptor<Product>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        guard let product = try modelContext.fetch(descriptor).first else { throw ProductStoreError.notFound }
        let date = now()
        edit(product, date)
        product.updatedAt = date
        product.needsSync = true
        try modelContext.save()
    }

    private static func clean(_ text: String?) -> String? {
        let clean = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean?.isEmpty == false ? String(clean!.prefix(300)) : nil
    }
}

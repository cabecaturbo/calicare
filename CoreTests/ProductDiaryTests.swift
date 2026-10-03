import Core
import Foundation
import SwiftData
import Testing

/// The product diary: products in use, stopped, and "never again" with the parent's reason.
struct ProductDiaryTests {
    private func store(_ harness: TestHarness) -> ProductStore {
        let clock = harness.clock
        return ProductStore(modelContainer: harness.container, now: { clock.now })
    }

    @Test func addStopAndNeverAgain() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let products = store(harness)
        let start = TestTime.date(1, 9)
        let cream = try await products.add(name: " Oat cream ", category: .moisturizer, startedAt: start, child: harness.child.id)
        let wash = try await products.add(name: "Lavender wash", category: .wash, startedAt: start, child: harness.child.id)
        #expect(cream.name == "Oat cream")
        #expect(cream.inUse)
        await #expect(throws: ProductStoreError.emptyName) {
            try await products.add(name: "  ", category: .other, startedAt: start, child: harness.child.id)
        }

        harness.clock.advance(minutes: 60)
        try await products.neverAgain(wash.id, reason: " Red cheeks after bath ")
        let after = try await products.products(child: harness.child.id)
        let never = try #require(after.first { $0.id == wash.id })
        #expect(never.neverAgain)
        #expect(never.reason == "Red cheeks after bath")
        #expect(never.stoppedAt == harness.clock.now)
        #expect(!never.inUse)

        try await products.resume(wash.id, from: harness.clock.now)
        let back = try #require(try await products.products(child: harness.child.id).first { $0.id == wash.id })
        #expect(back.inUse && back.reason == nil)

        try await products.stop(cream.id, on: TestTime.date(20, 9))
        try await products.delete(wash.id)
        let left = try await products.products(child: harness.child.id)
        #expect(left.map(\.name) == ["Oat cream"])
        #expect(left.first?.stoppedAt == TestTime.date(20, 9))
        #expect(left.first?.neverAgain == false)
    }

    @Test func kindIsGuessedFromTheName() {
        #expect(ProductCategory.guess(from: "Free & clear detergent") == .laundry)
        #expect(ProductCategory.guess(from: "Lavender wash") == .wash)
        #expect(ProductCategory.guess(from: "Cotton pajamas") == .clothing)
        #expect(ProductCategory.guess(from: "Oat cream") == .moisturizer)
        #expect(ProductCategory.guess(from: "Brand X") == nil)
    }

    @Test func productsJoinTheChanges() {
        let child = UUID()
        let wash = ProductInfo(id: UUID(), childID: child, name: "Lavender wash", category: .wash,
                               startedAt: TestTime.date(10, 9), stoppedAt: TestTime.date(20, 9), neverAgain: true,
                               reason: "Red cheeks", updatedAt: TestTime.date(20, 9))
        let shirt = ProductInfo(id: UUID(), childID: child, name: "Cotton pajamas", category: .clothing,
                                startedAt: TestTime.date(15, 9), stoppedAt: TestTime.date(18, 9), neverAgain: false,
                                reason: nil, updatedAt: TestTime.date(18, 9))
        let changes = CareChanges.list(plans: [], items: [:], logs: [], products: [wash, shirt])
        #expect(changes.map(\.text) == ["Never again: Lavender wash", "Stopped Cotton pajamas",
                                         "Started Cotton pajamas", "Started Lavender wash"])
        #expect(changes.allSatisfy { !$0.isFood })
    }

    @Test func v4DataSurvivesTheUpgrade() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("migration-v5-\(UUID().uuidString)").appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: url) }
        let childID = UUID()
        do {
            let schema = Schema(versionedSchema: SchemaV4.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(old)
            context.insert(SchemaV4.Child(id: childID, name: "Cal", colorTag: "sage"))
            context.insert(SchemaV4.Food(childID: childID, name: "Oats", family: nil, status: .safe, decidedBy: .parent))
            try context.save()
        }
        let context = ModelContext(try CaliCareModelContainer.make(url: url))
        #expect(try context.fetch(FetchDescriptor<Child>()).map(\.name) == ["Cal"])
        #expect(try context.fetchCount(FetchDescriptor<Food>()) == 1)
        context.insert(Product(childID: childID, name: "Oat cream", category: .moisturizer, startedAt: .now))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Product>()) == 1)
    }
}

import Core
import Foundation
import SwiftData
import Testing

/// The food list: statuses the parent or plan set, families, and the plan's avoid list.
struct FoodListTests {
    private func store(_ harness: TestHarness) -> FoodStore {
        let clock = harness.clock
        return FoodStore(modelContainer: harness.container, now: { clock.now })
    }

    @Test func addMoveAndFamilies() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let foods = store(harness)
        let oats = try await foods.add(name: " Oats ", status: .safe, decidedBy: .parent, child: harness.child.id)
        let eggs = try await foods.add(name: "Eggs", status: .paused, decidedBy: .plan, child: harness.child.id)
        #expect(oats.family == "Grasses (grains)")
        #expect(eggs.family == "Poultry")
        await #expect(throws: FoodStoreError.duplicate) {
            try await foods.add(name: "eggs", status: .safe, decidedBy: .parent, child: harness.child.id)
        }

        harness.clock.advance(minutes: 60)
        try await foods.setStatus(eggs.id, .testing, decidedBy: .parent)
        let moved = try #require(try await foods.foods(child: harness.child.id).first { $0.id == eggs.id })
        #expect(moved.status == .testing)
        #expect(moved.decidedBy == .parent)
        #expect(moved.statusChangedAt == TestTime.date(26, 10))

        try await foods.setFamily(oats.id, "My grains")
        try await foods.delete(eggs.id)
        #expect(try await foods.foods(child: harness.child.id).map(\.family) == ["My grains"])
    }

    @Test func familiesFromTheTable() {
        #expect(FoodFamilies.family(for: "Blueberries") == "Heath family")
        #expect(FoodFamilies.family(for: "Tomatoes") == "Nightshades")
        #expect(FoodFamilies.family(for: "Sweet potatoes") == "Morning glory family")
        #expect(FoodFamilies.family(for: "Dragon fruit") == nil)
    }

    @Test func avoidListFromThePlan() {
        let rule = PlanItemInfo(id: UUID(), planID: UUID(), kind: .foodRule, text: "Avoid: dairy, eggs and peanuts.",
                                dose: nil, frequency: nil, timing: nil, duration: nil, sourcePage: 2, sourceLine: nil,
                                isConfirmed: true, order: 0)
        let other = PlanItemInfo(id: UUID(), planID: UUID(), kind: .foodRule, text: "4-day rotation by food family",
                                 dose: nil, frequency: nil, timing: nil, duration: nil, sourcePage: 2, sourceLine: nil,
                                 isConfirmed: true, order: 1)
        #expect(PlanFoods.avoided(in: [rule, other]) == ["Dairy", "Eggs", "Peanuts"])
    }

    @Test func v3DataSurvivesTheUpgrade() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("migration-v4-\(UUID().uuidString)").appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: url) }
        let childID = UUID()
        do {
            let schema = Schema(versionedSchema: SchemaV3.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(old)
            context.insert(SchemaV3.Child(id: childID, name: "Cal", colorTag: "sage"))
            context.insert(SchemaV3.CarePlan(childID: childID, provider: "Dr. Lee"))
            try context.save()
        }
        let context = ModelContext(try CaliCareModelContainer.make(url: url))
        #expect(try context.fetch(FetchDescriptor<Child>()).map(\.name) == ["Cal"])
        #expect(try context.fetchCount(FetchDescriptor<CarePlan>()) == 1)
        context.insert(Food(childID: childID, name: "Oats", family: nil, status: .safe, decidedBy: .parent))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Food>()) == 1)
    }
}

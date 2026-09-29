import Core
import Foundation
import SwiftData
import Testing

/// Care plans: drafts, confirming items, starting, and visits.
struct CarePlanStoreTests {
    private func store(_ harness: TestHarness) -> CarePlanStore {
        let clock = harness.clock
        return CarePlanStore(modelContainer: harness.container, now: { clock.now })
    }

    private let drafts = [
        PlanItemDraft(kind: .bath, text: "Oat bath", frequency: "3 times a week", sourcePage: 1, sourceLine: "Oat bath 3x/week"),
        PlanItemDraft(kind: .supplement, text: "Vitamin D", dose: nil, sourcePage: 2, sourceLine: "Vitamin D (dose at next visit)"),
        PlanItemDraft(kind: .topicalStep, text: "  Moisturize after bath ", timing: "evening", sourcePage: 1, sourceLine: "Moisturize after bath"),
    ]

    @Test func aDraftKeepsItemsInOrderWithTheirSourceAndBlanks() async throws {
        let harness = try await TestHarness()
        let plans = store(harness)
        let plan = try await plans.createDraft(child: harness.child.id, provider: " Dr. Lee ", items: drafts)
        let items = try await plans.items(plan: plan.id)

        #expect(plan.status == .draft)
        #expect(plan.provider == "Dr. Lee")
        #expect(items.map(\.text) == ["Oat bath", "Vitamin D", "Moisturize after bath"])
        #expect(items[1].dose == nil) // left blank, never filled in
        #expect(items[0].sourceLine == "Oat bath 3x/week")
        #expect(items.allSatisfy { !$0.isConfirmed })
    }

    @Test func startingKeepsOnlyConfirmedItemsAndEndsThePreviousPlan() async throws {
        let harness = try await TestHarness()
        let plans = store(harness)
        let first = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: drafts)
        let firstItems = try await plans.items(plan: first.id)

        await #expect(throws: CarePlanStoreError.nothingConfirmed) { try await plans.start(first.id) }

        try await plans.setConfirmed(firstItems[0].id, true)
        try await plans.setConfirmed(firstItems[2].id, true)
        let started = try await plans.start(first.id)
        #expect(started.status == .active)
        #expect(try await plans.items(plan: first.id).map(\.text) == ["Oat bath", "Moisturize after bath"])

        // A started plan can't be edited.
        await #expect(throws: CarePlanStoreError.notDraft) { try await plans.setConfirmed(firstItems[0].id, false) }

        let second = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: [drafts[0]])
        try await plans.setConfirmed(try await plans.items(plan: second.id)[0].id, true)
        try await plans.start(second.id)
        #expect(try await plans.activePlan(child: harness.child.id)?.id == second.id)
        #expect(try await plans.plans(child: harness.child.id).first { $0.id == first.id }?.status == .ended)
    }

    @Test func editsAndRemovalOnlyOnADraft() async throws {
        let harness = try await TestHarness()
        let plans = store(harness)
        let plan = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: drafts)
        let items = try await plans.items(plan: plan.id)

        try await plans.update(items[1].id, with: PlanItemDraft(kind: .supplement, text: "Vitamin D3", dose: "400 IU"))
        try await plans.remove(items[0].id)
        let after = try await plans.items(plan: plan.id)
        #expect(after.map(\.text) == ["Vitamin D3", "Moisturize after bath"])
        #expect(after[0].dose == "400 IU")
        #expect(after[0].sourceLine == "Vitamin D (dose at next visit)")
        await #expect(throws: CarePlanStoreError.emptyText) {
            try await plans.update(items[1].id, with: PlanItemDraft(kind: .supplement, text: " "))
        }
    }

    @Test func visitsNewestFirstAndTheLastOneThatHappened() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let plans = store(harness)
        try await plans.addVisit(child: harness.child.id, date: TestTime.date(2026, 8, 12, 10), provider: "Dr. Lee")
        try await plans.addVisit(child: harness.child.id, date: TestTime.date(2026, 10, 7, 10), provider: "Dr. Lee", notes: "Follow-up")
        #expect(try await plans.visits(child: harness.child.id).count == 2)
        #expect(try await plans.lastVisit(child: harness.child.id)?.date == TestTime.date(2026, 8, 12, 10))
    }

    @Test func v2DataSurvivesTheUpgrade() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-v3-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: url) }

        let childID = UUID()
        let stepID = UUID()
        do {
            let schema = Schema(versionedSchema: SchemaV2.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(old)
            let child = SchemaV2.Child(id: childID, name: "Cal", colorTag: "sage")
            context.insert(child)
            context.insert(SchemaV2.RoutineStep(id: stepID, childID: childID, name: "Bath", time: .evening, order: 0))
            context.insert(SchemaV2.LogEvent(child: child, type: .flare, value: nil, note: nil, timestamp: TestTime.date(26, 9),
                                             loggedBy: "Mom", entrySource: .widget, bodyAreas: [.hands], routineStepID: nil))
            try context.save()
        }

        let upgraded = try CaliCareModelContainer.make(url: url)
        let context = ModelContext(upgraded)
        #expect(try context.fetch(FetchDescriptor<Child>()).map(\.name) == ["Cal"])
        let steps = try context.fetch(FetchDescriptor<RoutineStep>())
        #expect(steps.map(\.id) == [stepID])
        #expect(steps.first?.planItemID == nil)
        #expect(try context.fetch(FetchDescriptor<LogEvent>()).first?.bodyAreas == [.hands])

        context.insert(CarePlan(childID: childID, provider: "Dr. Lee"))
        context.insert(Visit(childID: childID, date: TestTime.date(26, 9), provider: "Dr. Lee"))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<CarePlan>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 1)
    }

    @Test func blanksOnlyForItemsThatGiveSomeDetail() async throws {
        let harness = try await TestHarness()
        let plans = store(harness)
        let plan = try await plans.createDraft(child: harness.child.id, provider: "", items: [
            PlanItemDraft(kind: .supplement, text: "Vitamin D3", frequency: "daily", sourceLine: "Vitamin D3, dose at next visit, daily"),
            PlanItemDraft(kind: .supplement, text: "Add one at a time", sourceLine: "Add one at a time, 3–5 days apart."),
        ])
        let items = try await plans.items(plan: plan.id)
        #expect(items[0].blanks == [.dose])
        #expect(items[1].blanks.isEmpty)
    }
}

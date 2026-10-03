import Core
import Foundation
import SwiftData
import Testing

/// Care plan sync: only what the parent confirmed goes up; the file never does.
struct CarePlanSyncTests {
    let user = UUID()
    let container: ModelContainer
    let clock = TestClock(TestTime.date(26, 9))
    let settings = SyncSettings(suiteName: "test.\(UUID().uuidString)")

    init() throws {
        container = try CaliCareModelContainer.make(inMemory: true)
    }

    private func engine(_ remote: FakeSyncRemote) -> SyncEngine {
        SyncEngine(modelContainer: container, remote: remote, settings: settings, now: { [clock] in clock.now })
    }

    private var plans: CarePlanStore { CarePlanStore(modelContainer: container, now: { [clock] in clock.now }) }

    private func addChild() async throws -> ChildInfo {
        try await ChildStore(modelContainer: container, now: { [clock] in clock.now }).addChild(name: "Cal", colorTag: "sage")
    }

    private let drafts = [
        PlanItemDraft(kind: .bath, text: "Oat bath", frequency: "3 times a week", sourcePage: 1, sourceLine: "Oat bath 3x/week"),
        PlanItemDraft(kind: .supplement, text: "Vitamin D", sourcePage: 2, sourceLine: "Vitamin D (dose at next visit)"),
    ]

    @Test func aDraftStaysOnThePhoneUntilItStarts() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let plan = try await plans.createDraft(child: child.id, provider: "Dr. Lee", sourceFileName: "plan-1.pdf", items: drafts)

        let first = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(first.pushedPlans == 0)
        #expect(first.pushedPlanItems == 0)
        #expect(await remote.carePlans.isEmpty)
        #expect(await remote.planItems.isEmpty)

        let items = try await plans.items(plan: plan.id)
        try await plans.setConfirmed(items[0].id, true)
        clock.advance(minutes: 1)
        try await plans.start(plan.id)

        let second = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(second.pushedPlans == 1)
        #expect(second.pushedPlanItems == 1)
        let uploaded = try #require(await remote.carePlans[plan.id])
        #expect(uploaded.status == "active")
        #expect(uploaded.provider == "Dr. Lee")
        #expect(await remote.planItems.values.map(\.text) == ["Oat bath"])
        #expect(await remote.planItems[items[1].id] == nil) // never confirmed, never sent

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<CarePlan>(predicate: #Predicate { $0.needsSync })) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PlanItem>(predicate: #Predicate { $0.needsSync })) == 0)
    }

    @Test func theFileNameNeverLeavesThePhone() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let plan = try await plans.createDraft(child: child.id, provider: "Dr. Lee", sourceFileName: "plan-1.pdf", items: drafts)
        try await plans.setConfirmed(try await plans.items(plan: plan.id)[0].id, true)
        try await plans.start(plan.id)
        try await engine(remote).sync(userID: user, displayName: "Mom")

        let uploaded = try #require(await remote.carePlans[plan.id])
        let json = String(decoding: try JSONEncoder().encode(uploaded), as: UTF8.self)
        #expect(!json.contains("plan-1.pdf"))
        // And this phone still knows where its file is.
        #expect(try await plans.activePlan(child: child.id)?.sourceFileName == "plan-1.pdf")
    }

    @Test func itemsAndVisitsFromAnotherPhoneComeDown() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        try await engine(remote).sync(userID: user, displayName: "Mom")
        let household = try #require(settings.householdID)

        let planID = UUID()
        try await remote.upsert(carePlans: [RemoteCarePlan(
            id: planID, householdID: household, childID: child.id, provider: "Dr. Lee", planDate: nil, status: "active",
            startedAt: clock.now, endedAt: nil, createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        )])
        await remote.insert(planItem: RemotePlanItem(
            id: UUID(), householdID: household, planID: planID, childID: child.id, kind: "bath", text: "Oat bath",
            dose: nil, frequency: "3 times a week", timing: nil, duration: nil, sourcePage: 1, sourceLine: "Oat bath 3x/week",
            sortOrder: 0, createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        ))
        try await remote.upsert(visits: [RemoteVisit(
            id: UUID(), householdID: household, childID: child.id, date: TestTime.date(2026, 10, 7, 10), provider: "Dr. Lee",
            notes: nil, createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        )])

        let report = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(report.appliedPlans == 1)
        #expect(report.appliedPlanItems == 1)
        #expect(report.appliedVisits == 1)
        #expect(try await plans.activePlan(child: child.id)?.id == planID)
        let items = try await plans.items(plan: planID)
        #expect(items.map(\.text) == ["Oat bath"])
        #expect(items.first?.isConfirmed == true)
        #expect(try await plans.visits(child: child.id).count == 1)
    }

    @Test func foodsGoUpAndComeDown() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let foods = FoodStore(modelContainer: container, now: { [clock] in clock.now })
        let eggs = try await foods.add(name: "Eggs", status: .paused, decidedBy: .plan, child: child.id)
        let report = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(report.pushedFoods == 1)
        #expect(await remote.foods[eggs.id]?.status == "paused")
        #expect(await remote.foods[eggs.id]?.decidedBy == "plan")

        let household = try #require(settings.householdID)
        try await remote.upsert(foods: [RemoteFood(
            id: UUID(), householdID: household, childID: child.id, name: "Oats", family: "Grasses (grains)", status: "safe",
            statusChangedAt: clock.now, decidedBy: "parent", note: nil, createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        )])
        let second = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(second.appliedFoods == 1)
        #expect(try await foods.foods(child: child.id).map(\.name) == ["Eggs", "Oats"])
    }

    @Test func productsGoUpAndComeDown() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let products = ProductStore(modelContainer: container, now: { [clock] in clock.now })
        let wash = try await products.add(name: "Lavender wash", category: .wash, startedAt: clock.now, child: child.id)
        try await products.neverAgain(wash.id, reason: "Red cheeks")
        let report = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(report.pushedProducts == 1)
        #expect(await remote.products[wash.id]?.neverAgain == true)
        #expect(await remote.products[wash.id]?.reason == "Red cheeks")

        let household = try #require(settings.householdID)
        try await remote.upsert(products: [RemoteProduct(
            id: UUID(), householdID: household, childID: child.id, name: "Oat cream", category: "moisturizer",
            startedAt: clock.now, stoppedAt: nil, neverAgain: false, reason: nil, restockEveryDays: nil, restockedAt: nil,
            createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        )])
        let second = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(second.appliedProducts == 1)
        #expect(try await products.products(child: child.id).map(\.name) == ["Lavender wash", "Oat cream"])
    }

    @Test func stepWordingGoesUpAndComesDown() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let routine = RoutineStore(modelContainer: container, now: { [clock] in clock.now })
        let step = try await routine.add(name: "Moisturizer", time: .evening, child: child.id)
        _ = try await engine(remote).sync(userID: user, displayName: "Mom")
        let up = await remote.routineSteps[step.id]
        #expect(up?.label == "Put on moisturizer")
        #expect(up?.sourceText == "Moisturizer")
        #expect(up?.category == "apply")
        #expect(up?.kind == "task")

        var changed = try #require(up)
        changed.label = "Cream on arms"
        changed.updatedAt = clock.now.addingTimeInterval(60)
        try await remote.upsert(routineSteps: [changed])
        let second = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(second.appliedRoutineSteps == 1)
        let down = try #require(try await routine.steps(child: child.id).first)
        #expect(down.label == "Cream on arms")
        #expect(down.sourceText == "Moisturizer")
        #expect(down.name == "Moisturizer")
    }
}

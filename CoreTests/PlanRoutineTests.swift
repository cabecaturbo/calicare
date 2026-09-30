import Core
import Foundation
import Testing

/// A started plan's daily steps join Plan's routine; ending the plan takes them out.
struct PlanRoutineTests {
    @Test func morningEveningOrBothFromThePlansWords() {
        #expect(PlanRoutine.times(text: "Moisturize", timing: nil, frequency: "3–4x/day") == [.morning, .evening])
        #expect(PlanRoutine.times(text: "Balm", timing: "at bedtime", frequency: nil) == [.evening])
        #expect(PlanRoutine.times(text: "Rinse", timing: "every morning", frequency: "daily") == [.morning])
        #expect(PlanRoutine.times(text: "Oil", timing: "morning and night", frequency: nil) == [.morning, .evening])
        #expect(PlanRoutine.times(text: "Apply", timing: nil, frequency: nil) == [.morning, .evening])
    }

    @Test func startingAddsTheStepsAndEndingRemovesThem() async throws {
        let harness = try await TestHarness()
        let clock = harness.clock
        let plans = CarePlanStore(modelContainer: harness.container, now: { clock.now })
        let routine = RoutineStore(modelContainer: harness.container, now: { clock.now })
        let mine = try await routine.add(name: "Pajamas", time: .evening, child: harness.child.id)

        let plan = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: [
            PlanItemDraft(kind: .topicalStep, text: "Apply calendula balm", frequency: "3–4x/day"),
            PlanItemDraft(kind: .topicalStep, text: "Seal with oil", timing: "at bedtime"),
            PlanItemDraft(kind: .bath, text: "Oat bath", frequency: "3x/week"),
            PlanItemDraft(kind: .topicalStep, text: "Not checked"),
        ])
        let items = try await plans.items(plan: plan.id)
        for item in items.prefix(3) { try await plans.setConfirmed(item.id, true) }
        try await plans.start(plan.id)

        let evening = try await routine.steps(child: harness.child.id, time: .evening)
        let morning = try await routine.steps(child: harness.child.id, time: .morning)
        #expect(evening.map(\.name) == ["Pajamas", "Apply calendula balm", "Seal with oil"])
        #expect(morning.map(\.name) == ["Apply calendula balm"])
        #expect(evening[1].planItemID == items[0].id)

        try await plans.end(plan.id)
        #expect(try await routine.steps(child: harness.child.id).map(\.id) == [mine.id])
    }
}

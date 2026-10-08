import Core
import Foundation
import Testing

/// Plan tab: which plan steps are in use, and what a tap changes.
struct PlanUseTests {
    private let child = UUID()
    private let plan = UUID()

    private func item(_ kind: PlanItemKind, _ text: String, order: Int, giving: Bool? = nil, parent: UUID? = nil,
                      dose: String? = nil) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: plan, kind: kind, text: text, dose: dose, frequency: nil, timing: nil, duration: nil,
                     sourcePage: 1, sourceLine: text, isConfirmed: true, order: order, parentItemID: parent, isGiving: giving)
    }

    private func step(_ item: PlanItemInfo, _ time: RoutineTime, active: Bool = true, kind: StepKind = .task,
                      category: StepCategory? = nil) -> RoutineStepInfo {
        RoutineStepInfo(id: UUID(), childID: child, name: item.text, time: time, order: 0, isActive: active,
                        planItemID: item.id, category: category, kind: kind)
    }

    @Test func aStepIsInUseWhileAnyOfItsTimesIsOn() {
        let wash = item(.routineStep, "Wash face", order: 0)
        let aloe = item(.topicalStep, "Aloe vera", order: 1)
        let use = PlanUse(items: [wash, aloe], steps: [
            step(wash, .morning, active: false), step(wash, .evening),
            step(aloe, .morning, active: false), step(aloe, .evening, active: false),
        ])
        #expect(use.rows.map(\.isInUse) == [true, false])
        #expect(use.rows[0].meta == "AM · PM")
        #expect(use.rows[0].group == .routine)
        #expect(use.rows[1].group == .skin)
        #expect(use.line == "1 of 2 steps are in To do.")
    }

    @Test func aSkinStepSaysWhatItIsAndShowsItsIcon() {
        let aloe = item(.topicalStep, "Step 2: Aloe vera, 96% or more pure", order: 0)
        let step = RoutineStepInfo(id: UUID(), childID: child, name: aloe.text, time: .morning, order: 0, isActive: true,
                                   planItemID: aloe.id, label: "Apply aloe vera", detail: "96% or more pure. Plant Therapy brand.",
                                   category: .apply)
        let row = PlanUse(items: [aloe], steps: [step]).rows[0]
        #expect(row.name == "Apply aloe vera")
        #expect(row.detail == "96% or more pure. Plant Therapy brand.")
        #expect(PlanUse.detail(" if tolerated. ") == "If tolerated.")
        #expect(PlanUse.detail("  ") == nil)
        let withHow = PlanItemInfo(id: UUID(), planID: plan, kind: .supplement, text: "Gut Powder", dose: "1 tsp",
                                   frequency: nil, timing: "Mix into water.", duration: "Can take long-term", sourcePage: 1,
                                   sourceLine: nil, isConfirmed: true, order: 1, isGiving: true)
        #expect(PlanUse(items: [withHow], steps: []).rows[0].detail == "Mix into water. Can take long-term.")
    }

    @Test func supplementsFollowGivingAndMentionsAreForReading() {
        let drops = item(.supplement, "ADD Brand D Drops", order: 0, giving: true, dose: "8 drops")
        let notYet = item(.supplement, "Zinc", order: 1, giving: nil, dose: "1 tab")
        let mention = item(.supplement, "Consider adding fish oil", order: 2)
        let rule = item(.supplement, "Add one at a time, 3–5 days apart", order: 3)
        let use = PlanUse(items: [drops, notYet, mention, rule], steps: [])
        #expect(use.rows.map(\.name) == ["Brand D Drops", "Zinc"])
        #expect(use.rows.map(\.isInUse) == [true, false])
        #expect(use.reference.map(\.text) == ["Consider adding fish oil", "Add one at a time, 3–5 days apart"])
    }

    @Test func itemsThatNeverGoInToDoAreLeftOutOfTheCount() {
        let bath = item(.bath, "Oat bath 3x a week", order: 0)
        let food = item(.foodRule, "Rotate foods every 4 days", order: 1)
        let patch = item(.routineStep, "Patch test new products", order: 2) // no steps
        let noteOnly = item(.topicalStep, "Support the skin 3-4x per day", order: 3)
        let use = PlanUse(items: [bath, food, patch, noteOnly], steps: [step(noteOnly, .evening, kind: .note)])
        #expect(use.total == 0)
        #expect(use.reference.count == 4)
        #expect(use.line == "None of the 0 steps are in To do yet.")
    }

    @Test func aSplitListShowsItsItemsNotTheList() {
        let list = item(.supplement, "Continue A, B", order: 0, giving: true)
        let a = item(.supplement, "A", order: 1, giving: true, parent: list.id)
        let b = item(.supplement, "B", order: 2, giving: true, parent: list.id)
        let use = PlanUse(items: [list, a, b], steps: [])
        #expect(use.rows.map(\.name) == ["A", "B"])
        #expect(use.line == "All 2 steps are in To do.")
    }

    @Test func tapsChangeStepsOrGivingAndUseAllOnlyTouchesWhatsOff() {
        let wash = item(.routineStep, "Wash face", order: 0)
        let drops = item(.supplement, "Drops", order: 1, giving: false, dose: "2 drops")
        let morning = step(wash, .morning)
        let evening = step(wash, .evening)
        let use = PlanUse(items: [wash, drops], steps: [morning, evening])

        #expect(PlanUse.change(use.rows[0], to: false) == .steps([morning.id, evening.id], active: false))
        #expect(PlanUse.change(use.rows[1], to: true) == .giving(drops.id, true))
        #expect(use.changeAll(to: true) == [.giving(drops.id, true)])
        #expect(use.changeAll(to: false) == [.steps([morning.id, evening.id], active: false)])
        #expect(use.changeAll(to: true, in: .routine).isEmpty)
    }

    @Test func turningAStepOffTakesItOutOfToDo() async throws {
        let harness = try await TestHarness()
        let clock = harness.clock
        let plans = CarePlanStore(modelContainer: harness.container, now: { clock.now })
        let routine = RoutineStore(modelContainer: harness.container, now: { clock.now })
        let draft = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: [
            PlanItemDraft(kind: .routineStep, text: "Wash face", timing: "morning"),
            PlanItemDraft(kind: .supplement, text: "Vitamin D", dose: "400 IU"),
        ])
        for item in try await plans.items(plan: draft.id) { try await plans.setConfirmed(item.id, true) }
        try await plans.start(draft.id)

        func current() async throws -> PlanUse {
            PlanUse(items: try await plans.items(plan: draft.id),
                    steps: try await routine.steps(child: harness.child.id, includeInactive: true))
        }
        let actions = PlanUseActions(routine: routine, plans: plans)
        try await actions.apply(try await current().changeAll(to: true))
        #expect(try await current().line == "All 2 steps are in To do.")

        let wash = try #require(try await current().rows.first { $0.name.contains("face") || $0.name.contains("Wash") })
        try await actions.apply([PlanUse.change(wash, to: false)])
        #expect(try await current().inUse == 1)
        #expect(try await routine.steps(child: harness.child.id).isEmpty) // To do reads active steps only
    }
}

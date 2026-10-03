import Core
import Foundation
import SwiftData
import Testing

/// Labels: a verb first, one action, at most 6 words, no "Step N:", and the
/// plan's numbers, brands, and ratios copied exactly, never made up.
struct StepLabelerTests {
    @Test func labelsFromThePlansWords() {
        let one = StepLabeler.wording(for: "Step 1: Active Skin Repair, if tolerated. If Cal doesn’t tolerate this step, move to Step 3.",
                                      planKind: .topicalStep)
        #expect(one.label == "Put on Active Skin Repair")
        #expect(one.detail == "if tolerated. If Cal doesn’t tolerate this step, move to Step 3.")
        #expect(one.category == .apply)
        #expect(one.kind == .task)

        let three = StepLabeler.wording(for: "Step 3: Jojoba oil + Neem oil. Start with 50:50 ratio and work up, as tolerated. Kate Blanc Brand on Amazon.",
                                        planKind: .topicalStep)
        #expect(three.label == "Put on Jojoba oil + Neem oil")
        #expect(three.detail?.contains("50:50") == true)

        #expect(StepLabeler.wording(for: "Bath").label == "Give a bath")
        #expect(StepLabeler.wording(for: "Bath").category == .wash)
        #expect(StepLabeler.wording(for: "Wash face").label == "Wash face")
        #expect(StepLabeler.wording(for: "Moisturizer").label == "Put on moisturizer")
        #expect(StepLabeler.wording(for: "Pajamas").label == "Put on pajamas")
        #expect(StepLabeler.wording(for: "Pajamas").category == .dress)
    }

    @Test func frequencyAndDurationLinesAreNotes() {
        let often = StepLabeler.wording(for: "Support the skin 3-4x per day, when possible", planKind: .routineStep, frequency: "3-4x per day")
        #expect(often.kind == .note)
        #expect(often.label == nil)
        #expect(StepLabeler.frequencyPhrase(in: "Support the skin 3-4x per day, when possible") == "3-4x per day")
        let long = StepLabeler.wording(for: "Continue a supportive topical routine for 60-90 days past when the skin is clear",
                                       planKind: .topicalStep, duration: "60-90 days past when the skin is clear")
        #expect(long.kind == .note)
    }

    @Test func everyLabelFollowsTheRules() {
        let lines = LegacyPlanFixture.items.map(\.text) + LegacyPlanFixture.steps.map(\.name) + [
            "Seal with plain oil", "Rinse with lukewarm water", "Apply calendula balm to affected areas",
            "Wet wraps overnight, as tolerated", "Mittens", "Cotton sleeves at bedtime",
        ]
        for line in lines {
            let wording = StepLabeler.wording(for: line)
            guard let label = wording.label else { continue }
            let words = label.split(separator: " ").filter { $0.contains(where: \.isLetter) }
            #expect(words.count <= StepLabeler.maxWords, "\(label)")
            #expect(!label.lowercased().hasPrefix("step"), "\(label)")
            #expect(StepLabeler.isValid(label: label, detail: wording.detail, source: StepLabeler.clean(line)), "\(label)")
        }
    }

    @Test func madeUpWordsAreRejected() {
        let source = "Aloe vera, 96% or more pure. Plant Therapy brand."
        #expect(StepLabeler.isValid(label: "Apply Aloe vera", detail: "96% or more pure. Plant Therapy brand.", source: source))
        #expect(!StepLabeler.isValid(label: "Apply Aloe vera", detail: "99% pure", source: source))
        #expect(!StepLabeler.isValid(label: "Apply Aloe vera", detail: "twice daily", source: source))
        #expect(!StepLabeler.isValid(label: "Apply Brand X aloe", detail: nil, source: source))
        #expect(!StepLabeler.isValid(label: "Aloe vera", detail: nil, source: source))
        #expect(!StepLabeler.isValid(label: "Step 1: Apply aloe", detail: nil, source: source))
        #expect(!StepLabeler.isValid(label: "Apply aloe vera to the arms and legs twice", detail: nil, source: source))
    }

    @Test func timesPerDay() {
        #expect(StepLabeler.timesPerDay("2x per day") == 2)
        #expect(StepLabeler.timesPerDay("3x daily") == 3)
        #expect(StepLabeler.timesPerDay("once daily") == 1)
        #expect(StepLabeler.timesPerDay("3-4x per day") == nil)
        #expect(StepLabeler.timesPerDay("3x per week") == nil)
    }

    @Test func renamingChangesOnlyTheLabel() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let routine = RoutineStore(modelContainer: harness.container)
        let step = try await routine.add(name: "Moisturizer", time: .evening, child: harness.child.id)
        #expect(step.sourceText == "Moisturizer")
        #expect(step.label == "Put on moisturizer")
        try await routine.rename(step.id, to: "Cream on arms")
        let after = try #require(try await routine.steps(child: harness.child.id).first)
        #expect(after.label == "Cream on arms")
        #expect(after.sourceText == "Moisturizer")
        #expect(after.name == "Moisturizer")
    }

    @Test func applyStepsGroupUnderSkin() {
        let child = UUID()
        func step(_ name: String, _ order: Int, _ category: StepCategory?, _ kind: StepKind = .task) -> RoutineStepInfo {
            RoutineStepInfo(id: UUID(), childID: child, name: name, time: .evening, order: order, isActive: true,
                            label: name, sourceText: name, category: category, kind: kind)
        }
        let layout = RoutineLayout(steps: [
            step("Take a bath", 0, .wash), step("Apply moisturizer", 1, .apply), step("Put on pajamas", 2, .dress),
            step("Support the skin 3-4x per day", 3, .apply, .note),
            step("Apply A", 4, .apply), step("Apply B", 5, .apply), step("Apply C", 6, .apply),
        ])
        #expect(layout.applyBadge == "3-4x per day")
        #expect(layout.notes.count == 1)
        #expect(layout.entries.count == 4)
        if case .skin(let steps) = layout.entries.last { #expect(steps.map(\.displayName) == ["Apply A", "Apply B", "Apply C"]) } else {
            Issue.record("expected a Skin group last")
        }
        #expect(layout.tasks.count == 6)
    }

    @Test func draftsKeepOnlyLabelsMadeOfThePlansWords() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let plans = CarePlanStore(modelContainer: harness.container)
        let line = "Step 2: Aloe vera, 96% or more pure. Plant Therapy brand."
        let draft = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: [
            PlanItemDraft(kind: .topicalStep, text: line, sourcePage: 1, sourceLine: line,
                          label: "Apply aloe vera", detail: "96% or more pure", category: .apply),
            PlanItemDraft(kind: .topicalStep, text: line, sourcePage: 1, sourceLine: line,
                          label: "Apply aloe vera", detail: "99% pure, twice daily", category: .apply),
        ])
        let items = try await plans.items(plan: draft.id)
        #expect(items[0].label == "Apply aloe vera")
        #expect(items[0].detail == "96% or more pure")
        #expect(items[1].label == nil)
        #expect(items[1].detail == nil)
        #expect(items.allSatisfy { $0.text == line })

        for item in items { try await plans.setConfirmed(item.id, true) }
        _ = try await plans.start(draft.id)
        let steps = try await RoutineStore(modelContainer: harness.container).steps(child: harness.child.id)
        #expect(steps.contains { $0.label == "Apply aloe vera" && $0.sourceText == line })
        #expect(steps.contains { $0.label == "Put on aloe vera" && $0.detail == "96% or more pure. Plant Therapy brand." })
    }

    @Test func cleanSlateRemovesPlansAndStepsButKeepsLogs() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let plans = CarePlanStore(modelContainer: harness.container)
        let routine = RoutineStore(modelContainer: harness.container)
        let mine = try await routine.add(name: "Bath", time: .evening, child: harness.child.id)
        let draft = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: LegacyPlanFixture.items)
        for item in try await plans.items(plan: draft.id) { try await plans.setConfirmed(item.id, true) }
        _ = try await plans.start(draft.id)
        let logs = LogStore(modelContainer: harness.container)
        _ = try await logs.logRoutineStep(mine.id, source: .app)
        let before = try await logs.allLive().count

        let removed = try await plans.removeAllPlansAndSteps(child: harness.child.id)
        #expect(removed > 0)
        #expect(try await plans.plans(child: harness.child.id).isEmpty)
        #expect(try await routine.steps(child: harness.child.id, includeInactive: true).isEmpty)
        #expect(try await logs.allLive().count == before)
    }

    @Test func appLabelsRefreshButParentLabelsStay() throws {
        let container = try CaliCareModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let old = RoutineStep(childID: UUID(), name: "Moisturizer", time: .evening, order: 0)
        old.sourceText = "Moisturizer"
        old.label = "Apply moisturizer"
        let mine = RoutineStep(childID: UUID(), name: "Bath", time: .evening, order: 1)
        mine.sourceText = "Bath"
        mine.label = "Bath with Grandma"
        context.insert(old)
        context.insert(mine)
        try context.save()
        let result = try StepBackfill.run(in: context)
        #expect(result.relabelled == 1)
        #expect(old.label == "Put on moisturizer")
        #expect(mine.label == "Bath with Grandma")
        #expect(old.name == "Moisturizer" && old.sourceText == "Moisturizer")
    }
}

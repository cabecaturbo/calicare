import Core
import Foundation
import SwiftData
import Testing

/// Plan v3: sections, meta lines, start and stop, and the provider's words.
struct PlanEntriesTests {
    private let child = UUID()
    private let plan = UUID()
    private let calendar = TestTime.calendar

    private func item(_ kind: PlanItemKind, _ text: String, order: Int, giving: Bool? = nil, dose: String? = nil,
                      frequency: String? = nil, source: String? = nil, paragraph: String? = nil) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: plan, kind: kind, text: text, dose: dose, frequency: frequency, timing: nil,
                     duration: nil, sourcePage: 1, sourceLine: source ?? text, isConfirmed: true, order: order,
                     isGiving: giving, sourceParagraph: paragraph)
    }

    private func step(_ item: PlanItemInfo, _ time: RoutineTime, label: String, active: Bool = true,
                      kind: StepKind = .task, created: Date = TestTime.date(12, 9), updated: Date = TestTime.date(12, 9)) -> RoutineStepInfo {
        RoutineStepInfo(id: UUID(), childID: child, name: item.text, time: time, order: 0, isActive: active,
                        planItemID: item.id, label: label, category: .apply, kind: kind,
                        createdAt: created, updatedAt: updated)
    }

    @Test func sectionsComeInOrderAndEmptyOnesAreLeftOut() {
        let food = item(.foodRule, "Avoid dairy", order: 0)
        let aloe = item(.topicalStep, "Step 2: Aloe vera", order: 1)
        let note = item(.topicalStep, "Aim to support the skin 3-4x per day", order: 2)
        let home = item(.fundamental, "Open windows 10 minutes daily", order: 3, frequency: "daily")
        let entries = PlanEntries(items: [food, aloe, note, home],
                                  steps: [step(aloe, .morning, label: "Apply aloe vera"),
                                          step(note, .evening, label: "Support the skin", kind: .note)],
                                  logs: [], calendar: calendar)
        #expect(entries.sections.map(\.section) == [.skin, .food, .home, .notes])
        #expect(entries.entry(note.id)?.kind == .reading)
        #expect(entries.entry(home.id)?.meta == "daily")
        #expect(PlanEntries(items: [item(.bath, "Oat bath", order: 0, frequency: "3x/week")], steps: [], logs: [], calendar: calendar).all[0].meta == "3 times a week")
    }

    @Test func skinStepsSayWhichStepAndHowOften() {
        let aloe = item(.topicalStep, "Step 2: Aloe vera, 96% or more pure", order: 0)
        let note = item(.routineStep, "Aim to support the skin 3-4x per day, when possible", order: 1)
        let entries = PlanEntries(items: [aloe, note], steps: [step(aloe, .morning, label: "Apply aloe vera"),
                                                                step(aloe, .evening, label: "Apply aloe vera")],
                                  logs: [], calendar: calendar)
        let entry = try! #require(entries.entry(aloe.id))
        #expect(entry.label == "Apply aloe vera")
        #expect(entry.meta == "Step 2 · 3 to 4 times a day")
        #expect(entry.status == .active(since: TestTime.date(12, 9)))
        #expect(entry.times.map(\.block) == [.morning, .bedtime])
    }

    @Test func supplementMetaFollowsItsStatus() {
        let gut = item(.supplement, "ADD ION Gut Support", order: 0, giving: true, dose: "1 teaspoon", frequency: "2x per day")
        let coptis = item(.supplement, "ADD Coptis", order: 1, giving: false, dose: "8 drops")
        let zinc = item(.supplement, "ADD Zinc", order: 2, giving: false, dose: "2 ml")
        let logs = [
            LogEntry(childID: child, type: .supplement, value: .supplement(.started), timestamp: TestTime.date(1, 9), routineStepID: zinc.id),
            LogEntry(childID: child, type: .supplement, value: .supplement(.stopped), timestamp: TestTime.date(30, 9), routineStepID: zinc.id),
        ]
        let entries = PlanEntries(items: [gut, coptis, zinc], steps: [], logs: logs, calendar: calendar)
        #expect(entries.all.map(\.label) == ["Give ION Gut Support", "Give Coptis", "Give Zinc"])
        #expect(entries.all.map(\.meta) == ["1 teaspoon · Morning and bedtime", "Not started yet", "Stopped Sep 30"])
        #expect(PlanWords.status(entries.all[0].status, calendar: calendar) == "In your daily list")
    }

    @Test func plainWords() {
        #expect(PlanWords.timesADay("3-4x per day") == "3 to 4 times a day")
        #expect(PlanWords.timesADay("2x daily") == "2 times a day")
        #expect(PlanWords.timesADay("once daily") == "once a day")
        #expect(PlanWords.timesADay("3x/week") == "3 times a week")
        #expect(PlanWords.timesADay("as needed") == nil)
        #expect(PlanWords.blocks([.bedtime, .morning]) == "Morning and bedtime")
        #expect(PlanWords.blocks(TodoBlock.allCases) == "Morning, afternoon, and bedtime")
    }

    @Test func theProvidersWordsAreNeverCut() {
        let long = String(repeating: "Apply a thin layer after the bath and let it soak in before pajamas. ", count: 9)
        #expect(long.count > 600)
        let rule = item(.foodRule, "Rotate foods", order: 0, paragraph: long)
        #expect(PlanEntries(items: [rule], steps: [], logs: [], calendar: calendar).all[0].words == long)
    }

    // MARK: - Start and stop, through the stores To do reads

    private struct Running {
        let harness: TestHarness
        let plans: CarePlanStore
        let routine: RoutineStore
        let logs: LogStore
        let actions: PlanEntryActions
        let planID: UUID

        func entries() async throws -> PlanEntries {
            PlanEntries(items: try await plans.items(plan: planID),
                        steps: try await routine.steps(child: harness.child.id, includeInactive: true),
                        logs: try await logs.allLive().filter { $0.type == .supplement }, calendar: TestTime.calendar)
        }

        func todo() async throws -> TodoDay {
            TodoDay(steps: try await routine.steps(child: harness.child.id, includeInactive: true),
                    items: try await plans.items(plan: planID), logs: try await logs.allLive(), times: [:],
                    now: harness.clock.now, calendar: TestTime.calendar)
        }
    }

    private func running() async throws -> Running {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let clock = harness.clock
        let plans = CarePlanStore(modelContainer: harness.container, now: { clock.now })
        let routine = RoutineStore(modelContainer: harness.container, now: { clock.now })
        let draft = try await plans.createDraft(child: harness.child.id, provider: "Dr. Lee", items: [
            PlanItemDraft(kind: .routineStep, text: "Wash face", timing: "morning"),
            PlanItemDraft(kind: .supplement, text: "Vitamin D", dose: "400 IU", frequency: "2x per day"),
        ])
        for item in try await plans.items(plan: draft.id) { try await plans.setConfirmed(item.id, true) }
        try await plans.start(draft.id)
        return Running(harness: harness, plans: plans, routine: routine, logs: harness.logs,
                       actions: PlanEntryActions(container: harness.container, child: harness.child.id, now: { clock.now }),
                       planID: draft.id)
    }

    private func labels(_ todo: TodoDay) -> [String] { todo.blocks.flatMap(\.items).map(\.label) }

    @Test func startingASupplementPutsItInToDoAtTheChosenTimes() async throws {
        let run = try await running()
        let vitamin = try #require(try await run.entries().all.first { $0.kind == .supplement })
        #expect(vitamin.status == .notStarted)
        #expect(!labels(try await run.todo()).contains("Give Vitamin D"))

        try await run.actions.start(vitamin, at: [.bedtime])
        let todo = try await run.todo()
        #expect(todo.blocks.first { $0.block == .bedtime }?.items.map(\.label).contains("Give Vitamin D") == true)
        #expect(todo.blocks.first { $0.block == .morning }?.items.map(\.label).contains("Give Vitamin D") == false)
        #expect(try await run.entries().entry(vitamin.id)?.status == .active(since: TestTime.date(26, 9)))
    }

    @Test func stoppingTakesItOutOfToDoAndKeepsHistory() async throws {
        let run = try await running()
        let wash = try #require(try await run.entries().all.first { $0.kind == .steps })
        #expect(labels(try await run.todo()).contains("Wash face"))

        // A step done this morning, then stopped.
        let stepID = try #require(wash.stepIDs[.morning])
        _ = try await run.logs.logRoutineStep(stepID, source: .app)
        let before = try await run.logs.allLive().count
        run.harness.clock.advance(minutes: 60)
        try await run.actions.stop(wash)

        #expect(!labels(try await run.todo()).contains("Wash face"))
        #expect(try await run.logs.allLive().count == before)
        #expect(try await run.entries().entry(wash.id)?.status == .stopped(on: run.harness.clock.now))

        // Adding it back again, at bedtime too: the missing evening step is made.
        let stopped = try #require(try await run.entries().entry(wash.id))
        try await run.actions.start(stopped, at: [.morning, .bedtime])
        let back = try #require(try await run.entries().entry(wash.id))
        #expect(back.isActive)
        #expect(back.times.filter(\.isOn).map(\.block) == [.morning, .bedtime])
    }
}

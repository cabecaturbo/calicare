import Core
import Foundation
import SwiftData
import Testing

/// Data saved by the version on the phone today (SchemaV5) opens in V6 and the
/// wording backfill runs: every step, supplement, and log comes through as it
/// was; only the new fields are filled.
struct StepWordingUpgradeTests {
    private struct Saved {
        var steps: [UUID: (name: String, time: String, order: Int, planItemID: UUID?)] = [:]
        var items: [UUID: String] = [:]
        var logs: [UUID: (type: String, stepID: UUID?, timestamp: Date)] = [:]
    }

    /// A V5 store shaped like the owner's phone: parent steps, plan steps cut to
    /// 80 characters and linked to their items, supplements, and logs.
    private func makeV5Store(at url: URL) throws -> Saved {
        let schema = Schema(versionedSchema: SchemaV5.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let context = ModelContext(container)
        let child = SchemaV5.Child(name: "Cal", colorTag: "sage")
        context.insert(child)
        let plan = SchemaV5.CarePlan(childID: child.id, provider: "Dr. Rivera")
        plan.statusRaw = CarePlanStatus.active.rawValue
        plan.startedAt = .now
        context.insert(plan)
        var saved = Saved()
        var order = [RoutineTime.morning: 0, .evening: 0]
        for step in LegacyPlanFixture.steps {
            let row = SchemaV5.RoutineStep(childID: child.id, name: step.name, time: step.time, order: order[step.time]!)
            order[step.time]! += 1
            context.insert(row)
            saved.steps[row.id] = (row.name, row.timeRaw, row.order, nil)
        }
        for (index, draft) in LegacyPlanFixture.items.enumerated() {
            let item = SchemaV5.PlanItem(planID: plan.id, childID: child.id, kind: draft.kind, text: draft.text, dose: draft.dose,
                                         frequency: draft.frequency, timing: draft.timing, duration: draft.duration,
                                         sourcePage: draft.sourcePage, sourceLine: draft.sourceLine, order: index)
            item.isConfirmed = true
            context.insert(item)
            saved.items[item.id] = item.text
            guard PlanRoutine.isDailyStep(kind: draft.kind, text: draft.text) else { continue }
            for time in RoutineTime.allCases {
                let row = SchemaV5.RoutineStep(childID: child.id, name: String(draft.text.prefix(80)), time: time,
                                               order: order[time]!, planItemID: item.id)
                order[time]! += 1
                context.insert(row)
                saved.steps[row.id] = (row.name, row.timeRaw, row.order, item.id)
            }
        }
        for (stepID, _) in saved.steps.prefix(4) {
            let log = SchemaV5.LogEvent(child: child, type: .routineDone, value: nil, note: nil, timestamp: .now,
                                        loggedBy: "Mom", entrySource: .app, routineStepID: stepID)
            context.insert(log)
            saved.logs[log.id] = (log.typeRaw, stepID, log.timestamp)
        }
        try context.save()
        return saved
    }

    @Test func everythingSurvivesAndOnlyNewFieldsFill() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("migration-v6-\(UUID().uuidString)").appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: url) }
        let saved = try makeV5Store(at: url)
        #expect(saved.steps.values.contains { $0.name.count == 80 })

        let context = ModelContext(try CaliCareModelContainer.make(url: url))
        let result = try StepBackfill.run(in: context)
        #expect(result.needsReentry.isEmpty)

        // Steps: same ids, names, times, order, and plan links.
        let steps = try context.fetch(FetchDescriptor<RoutineStep>())
        #expect(steps.count == saved.steps.count)
        for step in steps {
            let before = try #require(saved.steps[step.id])
            #expect(step.name == before.name)
            #expect(step.timeRaw == before.time)
            #expect(step.order == before.order)
            #expect(step.planItemID == before.planItemID)
            #expect(step.deletedAt == nil)
            #expect(step.sourceText != nil)
        }
        // Cut-off names get their full words back from the plan line.
        let calendula = try #require(steps.first { $0.name.hasPrefix("Step 1: Calendula") })
        #expect(calendula.sourceText == "Step 1: Calendula cream, if tolerated. If Cal doesn’t tolerate this step, move straight to Step 3.")
        #expect(calendula.label == "Apply calendula cream")
        #expect(calendula.detail == "if tolerated. If Cal doesn’t tolerate this step, move straight to Step 3.")
        #expect(steps.first { $0.name.hasPrefix("Support the skin") }?.kindRaw == "note")

        // Plan items: every original is still there, unchanged; the "Continue" list adds two.
        let items = try context.fetch(FetchDescriptor<PlanItem>())
        for (id, text) in saved.items {
            #expect(items.first { $0.id == id }?.text == text)
            #expect(items.first { $0.id == id }?.deletedAt == nil)
        }
        let split = items.filter { $0.parentItemID != nil }.map(\.text).sorted()
        #expect(split == ["Fish Oil", "Vitamin D"])
        #expect(items.filter { $0.parentItemID != nil }.allSatisfy { $0.sourceLine == "Continue Vitamin D, Fish Oil" })

        // Logs: same ids, types, steps, and times.
        let logs = try context.fetch(FetchDescriptor<LogEvent>())
        #expect(logs.count == saved.logs.count)
        for log in logs {
            let before = try #require(saved.logs[log.id])
            #expect(log.typeRaw == before.type)
            #expect(log.routineStepID == before.stepID)
            #expect(log.timestamp == before.timestamp)
        }

        // Running it again changes nothing.
        let again = try StepBackfill.run(in: context)
        #expect(again.labelled == 0 && again.split == 0)
        #expect(try context.fetchCount(FetchDescriptor<PlanItem>()) == items.count)
    }

    @Test func aCutNameWithNoFullWordsIsListedForReentry() throws {
        let container = try CaliCareModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let name = String(repeating: "a", count: 76) + " end"
        context.insert(RoutineStep(childID: UUID(), name: name, time: .evening, order: 0, planItemID: UUID()))
        try context.save()
        let result = try StepBackfill.run(in: context)
        #expect(result.needsReentry == [name])
        #expect(try context.fetch(FetchDescriptor<RoutineStep>()).first?.name == name)
    }
}

import Core
import Foundation
import SwiftData
import Testing

struct RoutineStepTests {
    private func store(_ harness: TestHarness) -> RoutineStore {
        let clock = harness.clock
        return RoutineStore(modelContainer: harness.container, now: { clock.now })
    }

    @Test func stepsKeepTheirOrderWithinMorningAndEvening() async throws {
        let harness = try await TestHarness()
        let routine = store(harness)
        let bath = try await routine.add(name: " Bath ", time: .evening, child: harness.child.id)
        let cream = try await routine.add(name: "Moisturizer", time: .evening, child: harness.child.id)
        let wash = try await routine.add(name: "Wash face", time: .morning, child: harness.child.id)

        #expect(bath.name == "Bath")
        #expect(try await routine.steps(child: harness.child.id, time: .evening).map(\.id) == [bath.id, cream.id])
        #expect(try await routine.steps(child: harness.child.id, time: .morning).map(\.id) == [wash.id])
        #expect(wash.order == 0)
        #expect(cream.order == 1)
    }

    @Test func reorderRenamePauseAndRemove() async throws {
        let harness = try await TestHarness()
        let routine = store(harness)
        let a = try await routine.add(name: "Bath", time: .evening, child: harness.child.id)
        let b = try await routine.add(name: "Moisturizer", time: .evening, child: harness.child.id)
        let c = try await routine.add(name: "Wet wraps", time: .evening, child: harness.child.id)

        try await routine.reorder(child: harness.child.id, time: .evening, ids: [c.id, a.id])
        #expect(try await routine.steps(child: harness.child.id).map(\.id) == [c.id, a.id, b.id])

        try await routine.rename(b.id, to: "Cream")
        try await routine.setActive(a.id, false)
        #expect(try await routine.steps(child: harness.child.id).map(\.name) == ["Wet wraps", "Cream"])
        #expect(try await routine.steps(child: harness.child.id, includeInactive: true).count == 3)

        try await routine.delete(c.id)
        #expect(try await routine.steps(child: harness.child.id).map(\.id) == [b.id])
    }

    @Test func aStepNeedsANameAndAChild() async throws {
        let harness = try await TestHarness()
        let routine = store(harness)
        await #expect(throws: RoutineStoreError.emptyName) {
            try await routine.add(name: "  ", time: .morning, child: harness.child.id)
        }
        await #expect(throws: RoutineStoreError.childNotFound) {
            try await routine.add(name: "Bath", time: .morning, child: UUID())
        }
    }

    @Test func tickingOffAStepLogsRoutineDone() async throws {
        let harness = try await TestHarness()
        let step = try await store(harness).add(name: "Bath", time: .evening, child: harness.child.id)
        let entry = try await harness.logs.logRoutineStep(step.id, source: .app)
        #expect(entry.type == .routineDone)
        #expect(entry.value == .routine(.evening))
        #expect(entry.routineStepID == step.id)
        #expect(entry.childID == harness.child.id)

        await #expect(throws: LogStoreError.routineStepNotFound) {
            try await harness.logs.logRoutineStep(UUID(), source: .app)
        }
    }
}

struct BodyAreaTests {
    @Test func aFlareCanSayWhere() async throws {
        let harness = try await TestHarness()
        let entry = try await harness.logs.log(.flare, child: harness.child.id, source: .app, bodyAreas: [.face, .elbowCreases, .face])
        #expect(entry.bodyAreas == [.face, .elbowCreases])
    }

    @Test func onlyFlaresHaveBodyAreas() async throws {
        let harness = try await TestHarness()
        await #expect(throws: LogStoreError.bodyAreasNotAllowed) {
            try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .app, bodyAreas: [.hands])
        }
        let itch = try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .app)
        await #expect(throws: LogStoreError.bodyAreasNotAllowed) {
            try await harness.logs.setBodyAreas([.hands], on: itch.id)
        }
    }

    @Test func addWhereAfterLogging() async throws {
        let harness = try await TestHarness()
        let flare = try await harness.logs.log(.flare, child: harness.child.id, source: .widget)
        #expect(flare.bodyAreas.isEmpty)
        harness.clock.advance(minutes: 1)
        let updated = try await harness.logs.setBodyAreas([.kneeCreases, .feet], on: flare.id)
        #expect(updated.bodyAreas == [.kneeCreases, .feet])
        let stored = try harness.allStoredEvents().first { $0.id == flare.id }
        #expect(stored?.needsSync == true)
        #expect(try await harness.logs.setBodyAreas([], on: flare.id).bodyAreas.isEmpty)
    }

    @Test func areaWords() {
        #expect(BodyArea.diaperArea.words == "diaper area")
        #expect(BodyArea.face.words == "face")
    }
}

struct SchemaMigrationTests {
    /// Data saved by the version on the phone today (SchemaV1) must survive the upgrade.
    @Test func v1DataSurvivesTheUpgrade() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: url) }

        let childID = UUID()
        let logID = UUID()
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(old)
            let child = SchemaV1.Child(id: childID, name: "Cal", colorTag: "sage")
            context.insert(child)
            context.insert(SchemaV1.LogEvent(
                id: logID, child: child, type: .nightRating, value: .night(.rough), note: "Up twice",
                timestamp: TestTime.date(26, 7), loggedBy: "Mom", entrySource: .notification
            ))
            try context.save()
        }

        let upgraded = try CaliCareModelContainer.make(url: url)
        let context = ModelContext(upgraded)
        let children = try context.fetch(FetchDescriptor<Child>())
        let logs = try context.fetch(FetchDescriptor<LogEvent>())
        #expect(children.map(\.id) == [childID])
        #expect(children.first?.name == "Cal")
        #expect(logs.map(\.id) == [logID])
        #expect(logs.first?.value == .night(.rough))
        #expect(logs.first?.note == "Up twice")
        #expect(logs.first?.child?.id == childID)
        #expect(logs.first?.bodyAreas == [])
        #expect(logs.first?.routineStepID == nil)
        #expect(try context.fetchCount(FetchDescriptor<RoutineStep>()) == 0)

        // And the new model works in the upgraded store.
        context.insert(RoutineStep(childID: childID, name: "Bath", time: .evening, order: 0))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<RoutineStep>()) == 1)
    }
}

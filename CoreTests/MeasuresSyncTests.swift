import Core
import Foundation
import SwiftData
import Testing

/// Sync for the U2 measures: routine steps, flare body areas, and skin answers.
struct MeasuresSyncTests {
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

    private func addChild() async throws -> ChildInfo {
        try await ChildStore(modelContainer: container, now: { [clock] in clock.now }).addChild(name: "Cal", colorTag: "sage")
    }

    @Test func stepsAndTheirLogsGoUp() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let step = try await RoutineStore(modelContainer: container, now: { [clock] in clock.now })
            .add(name: "Bath", time: .evening, child: child.id)
        let logs = LogStore(modelContainer: container, now: { [clock] in clock.now })
        let done = try await logs.logRoutineStep(step.id, source: .app)
        let flare = try await logs.log(.flare, child: child.id, source: .app, bodyAreas: [.neck, .hands])

        let report = try await engine(remote).sync(userID: user, displayName: "Mom")

        #expect(report.pushedRoutineSteps == 1)
        let uploaded = try #require(await remote.routineSteps[step.id])
        #expect(uploaded.name == "Bath")
        #expect(uploaded.time == "evening")
        #expect(uploaded.childID == child.id)
        #expect(await remote.logs[done.id]?.routineStepID == step.id)
        #expect(await remote.logs[flare.id]?.bodyAreas == ["neck", "hands"])
        let pending = try ModelContext(container).fetchCount(FetchDescriptor<RoutineStep>(predicate: #Predicate { $0.needsSync }))
        #expect(pending == 0)
    }

    @Test func stepsAndAnswersFromAnotherPhoneComeDown() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        try await engine(remote).sync(userID: user, displayName: "Mom")
        let household = try #require(settings.householdID)

        let step = RemoteRoutineStep(
            id: UUID(), householdID: household, childID: child.id, name: "Wet wraps", time: "evening",
            sortOrder: 2, isActive: true, createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        )
        await remote.insert(step: step)
        let skin = RemoteLogEvent(
            id: UUID(), householdID: household, childID: child.id, type: "skinToday", value: "flaring",
            note: nil, occurredAt: TestTime.date(26, 18), loggedBy: "Dad", entrySource: "notification",
            createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        )
        let flare = RemoteLogEvent(
            id: UUID(), householdID: household, childID: child.id, type: "flare", value: nil,
            note: nil, occurredAt: TestTime.date(26, 12), loggedBy: "Dad", entrySource: "app",
            bodyAreas: ["back", "somethingNew"],
            createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        )
        await remote.insert(log: skin)
        await remote.insert(log: flare)

        let report = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(report.appliedRoutineSteps == 1)

        let steps = try await RoutineStore(modelContainer: container).steps(child: child.id)
        #expect(steps.map(\.name) == ["Wet wraps"])
        #expect(steps.first?.order == 2)

        let context = ModelContext(container)
        let flareID = flare.id
        let local = try #require(try context.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == flareID })).first)
        // Areas from a newer app version are kept in storage but not shown.
        #expect(local.bodyAreaNames == ["back", "somethingNew"])
        #expect(local.bodyAreas == [.back])
        let skinID = skin.id
        let answer = try context.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == skinID })).first
        #expect(answer?.value == .skin(.flaring))
    }

    @Test func signingInQueuesStepsToUpload() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        _ = try await RoutineStore(modelContainer: container).add(name: "Bath", time: .evening, child: child.id)
        // Pretend it was already uploaded under no account.
        let context = ModelContext(container)
        for step in try context.fetch(FetchDescriptor<RoutineStep>()) { step.needsSync = false }
        try context.save()

        let report = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(report.pushedRoutineSteps == 1)
    }

    @Test func remoteRowsFromBeforeTheMigrationStillDecode() throws {
        let json = """
        {"id":"\(UUID())","household_id":"\(UUID())","child_id":null,"type":"itchEpisode","value":null,
         "note":null,"occurred_at":"2026-09-26T16:00:00Z","logged_by":"Mom","entry_source":"widget",
         "created_at":"2026-09-26T16:00:00Z","updated_at":"2026-09-26T16:00:00Z","deleted_at":null}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let row = try decoder.decode(RemoteLogEvent.self, from: Data(json.utf8))
        #expect(row.bodyAreas.isEmpty)
        #expect(row.routineStepID == nil)
    }
}

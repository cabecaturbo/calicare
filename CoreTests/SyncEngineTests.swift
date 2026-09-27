import Core
import Foundation
import SwiftData
import Testing

struct SyncEngineTests {
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

    private func logStore() -> LogStore {
        LogStore(modelContainer: container, now: { [clock] in clock.now })
    }

    private func addChild(_ name: String = "Cal") async throws -> ChildInfo {
        try await ChildStore(modelContainer: container, now: { [clock] in clock.now }).addChild(name: name, colorTag: "sage")
    }

    private func pendingCount() throws -> Int {
        let context = ModelContext(container)
        return try context.fetchCount(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.needsSync }))
            + context.fetchCount(FetchDescriptor<Child>(predicate: #Predicate { $0.needsSync }))
    }

    private func localLog(_ id: UUID) throws -> LogEvent? {
        try ModelContext(container).fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.id == id })).first
    }

    @Test func pushUploadsLogsAndClearsTheFlag() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let entry = try await logStore().log(.itchEpisode, child: child.id, source: .widget)

        let report = try await engine(remote).sync(userID: user, displayName: "Mom")

        #expect(report.pushedChildren == 1)
        #expect(report.pushedLogs == 1)
        let uploaded = try #require(await remote.logs[entry.id])
        #expect(uploaded.type == "itchEpisode")
        #expect(uploaded.childID == child.id)
        #expect(uploaded.entrySource == "widget")
        #expect(try pendingCount() == 0)
        #expect(settings.lastSyncedAt == clock.now)
    }

    @Test func pullBringsInLogsFromAnotherPhone() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        try await engine(remote).sync(userID: user, displayName: "Mom")
        let household = try #require(settings.householdID)

        let fromDad = RemoteLogEvent(
            id: UUID(), householdID: household, childID: child.id, type: "nightRating", value: "rough",
            note: "Up twice", occurredAt: clock.now, loggedBy: "Dad", entrySource: "intent",
            createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        )
        await remote.insert(log: fromDad)
        let report = try await engine(remote).sync(userID: user, displayName: "Mom")

        #expect(report.appliedLogs == 1)
        let local = try #require(try localLog(fromDad.id))
        #expect(local.type == .nightRating)
        #expect(local.value == .night(.rough))
        #expect(local.loggedBy == "Dad")
        #expect(local.child?.id == child.id)
        #expect(!local.needsSync)
    }

    @Test func aNewerServerEditWinsOverAnOlderLocalOne() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let entry = try await logStore().log(.itchEpisode, child: child.id, source: .app)
        try await engine(remote).sync(userID: user, displayName: "Mom")

        // This phone edits at 9:05 but hasn't synced; another phone edits at 9:10.
        clock.advance(minutes: 5)
        _ = try await logStore().update(entry.id, value: nil, note: "mine", timestamp: entry.timestamp)
        await remote.edit(log: entry.id) {
            $0.note = "theirs"
            $0.updatedAt = clock.now.addingTimeInterval(300)
        }
        try await engine(remote).sync(userID: user, displayName: "Mom")

        #expect(try localLog(entry.id)?.note == "theirs")
        #expect(await remote.logs[entry.id]?.note == "theirs")
    }

    @Test func aNewerLocalEditWinsOverAnOlderServerOne() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let entry = try await logStore().log(.itchEpisode, child: child.id, source: .app)
        try await engine(remote).sync(userID: user, displayName: "Mom")

        await remote.edit(log: entry.id) {
            $0.note = "theirs"
            $0.updatedAt = clock.now.addingTimeInterval(60)
        }
        clock.advance(minutes: 10)
        _ = try await logStore().update(entry.id, value: nil, note: "mine", timestamp: entry.timestamp)
        try await engine(remote).sync(userID: user, displayName: "Mom")

        #expect(try localLog(entry.id)?.note == "mine")
        #expect(await remote.logs[entry.id]?.note == "mine")
    }

    @Test func deletesSyncAsDeletedAtBothWays() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        let mine = try await logStore().log(.itchEpisode, child: child.id, source: .app)
        let theirs = try await logStore().log(.flare, child: child.id, source: .app)
        try await engine(remote).sync(userID: user, displayName: "Mom")

        clock.advance(minutes: 1)
        _ = try await logStore().delete(mine.id)
        await remote.edit(log: theirs.id) {
            $0.deletedAt = clock.now
            $0.updatedAt = clock.now.addingTimeInterval(1)
        }
        try await engine(remote).sync(userID: user, displayName: "Mom")

        #expect(await remote.logs[mine.id]?.deletedAt != nil)
        #expect(await remote.logs[mine.id] != nil, "soft delete, never removed")
        #expect(try localLog(theirs.id)?.deletedAt != nil)
    }

    @Test func offlineLogsWaitAndUploadLater() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        try await engine(remote).sync(userID: user, displayName: "Mom")

        await remote.setOffline(true)
        let entry = try await logStore().log(.itchEpisode, child: child.id, source: .notification)
        await #expect(throws: Offline.self) { try await engine(remote).sync(userID: user, displayName: "Mom") }
        #expect(try pendingCount() == 1)

        await remote.setOffline(false)
        try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(await remote.logs[entry.id] != nil)
        #expect(try pendingCount() == 0)
    }

    @Test func firstSignInMakesAHouseholdAndUploadsEverything() async throws {
        let remote = FakeSyncRemote()
        // Logged for weeks with no account: everything was already "synced" nowhere.
        let child = try await addChild()
        let entries = [
            try await logStore().log(.itchEpisode, child: child.id, source: .widget),
            try await logStore().log(.nightRating, value: .night(.good), child: child.id, source: .notification),
        ]
        let context = ModelContext(container)
        for event in try context.fetch(FetchDescriptor<LogEvent>()) { event.needsSync = false }
        try context.save()

        try await engine(remote).sync(userID: user, displayName: "Mom")

        let household = try #require(settings.householdID)
        #expect(await remote.households.contains(household))
        #expect(await remote.children[child.id]?.householdID == household)
        for entry in entries {
            #expect(await remote.logs[entry.id]?.householdID == household)
        }
    }

    @Test func aSecondPhoneJoinsTheSameHouseholdAndGetsItsLogs() async throws {
        let household = UUID()
        let remote = FakeSyncRemote(existingHousehold: household)
        let childID = UUID()
        await remote.insert(child: RemoteChild(
            id: childID, householdID: household, name: "Cal", birthDate: nil, colorTag: "sage",
            isActive: true, createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        ))
        await remote.insert(log: RemoteLogEvent(
            id: UUID(), householdID: household, childID: childID, type: "itchEpisode", value: nil, note: nil,
            occurredAt: clock.now, loggedBy: "Mom", entrySource: "widget",
            createdAt: clock.now, updatedAt: clock.now, deletedAt: nil
        ))

        let report = try await engine(remote).sync(userID: user, displayName: "Dad")

        #expect(settings.householdID == household)
        #expect(report.appliedChildren == 1)
        #expect(report.appliedLogs == 1)
        let children = try await ChildStore(modelContainer: container).activeChildren()
        #expect(children.map(\.name) == ["Cal"])
    }

    @Test func theCursorOnlyBringsNewChanges() async throws {
        let remote = FakeSyncRemote()
        let child = try await addChild()
        _ = try await logStore().log(.itchEpisode, child: child.id, source: .app)
        try await engine(remote).sync(userID: user, displayName: "Mom")
        let cursor = try #require(settings.cursor)

        let again = try await engine(remote).sync(userID: user, displayName: "Mom")
        #expect(again.changedLocalData == false)
        #expect(again.pushedLogs == 0)
        #expect(settings.cursor == cursor)
    }
}

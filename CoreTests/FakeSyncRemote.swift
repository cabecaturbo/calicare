import Core
import Foundation

struct Offline: Error {}

/// An in-memory Supabase with the same rules as the real one: upserts keep
/// the newer updated_at, and every write gets a server time for "changes since".
actor FakeSyncRemote: SyncRemote {
    private(set) var children: [UUID: RemoteChild] = [:]
    private(set) var logs: [UUID: RemoteLogEvent] = [:]
    private(set) var households: Set<UUID> = []
    private var memberHousehold: UUID?
    private var serverClock = Date(timeIntervalSince1970: 2_000_000_000)
    var isOffline = false

    /// A household this person already belongs to (e.g. from another phone).
    init(existingHousehold: UUID? = nil) {
        memberHousehold = existingHousehold
        if let existingHousehold { households.insert(existingHousehold) }
    }

    func setOffline(_ offline: Bool) { isOffline = offline }

    func householdID() async throws -> UUID? {
        try check()
        return memberHousehold
    }

    func createHousehold(id: UUID, name: String, memberID: UUID, displayName: String) async throws {
        try check()
        households.insert(id)
        memberHousehold = id
    }

    func upsert(children rows: [RemoteChild]) async throws {
        try check()
        for var row in rows where isNewer(row.updatedAt, than: children[row.id]?.updatedAt) {
            row.serverUpdatedAt = tick()
            children[row.id] = row
        }
    }

    func upsert(logs rows: [RemoteLogEvent]) async throws {
        try check()
        for var row in rows where isNewer(row.updatedAt, than: logs[row.id]?.updatedAt) {
            row.serverUpdatedAt = tick()
            logs[row.id] = row
        }
    }

    func changes(household: UUID, since: Date?) async throws -> RemoteChanges {
        try check()
        let after = since ?? .distantPast
        return RemoteChanges(
            children: children.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after },
            logs: logs.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after }
        )
    }

    /// Another phone (or the dashboard) edits a log directly.
    func edit(log id: UUID, _ change: @Sendable (inout RemoteLogEvent) -> Void) {
        guard var row = logs[id] else { return }
        change(&row)
        row.serverUpdatedAt = tick()
        logs[id] = row
    }

    func insert(child: RemoteChild) {
        var row = child
        row.serverUpdatedAt = tick()
        children[row.id] = row
    }

    func insert(log: RemoteLogEvent) {
        var row = log
        row.serverUpdatedAt = tick()
        logs[row.id] = row
    }

    private func isNewer(_ incoming: Date, than stored: Date?) -> Bool {
        stored.map { incoming >= $0 } ?? true
    }

    private func tick() -> Date {
        serverClock = serverClock.addingTimeInterval(1)
        return serverClock
    }

    private func check() throws {
        if isOffline { throw Offline() }
    }
}

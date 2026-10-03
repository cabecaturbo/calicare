import Core
import Foundation

struct Offline: Error {}

/// An in-memory Supabase with the same rules as the real one: upserts keep
/// the newer updated_at, and every write gets a server time for "changes since".
actor FakeSyncRemote: SyncRemote {
    private(set) var children: [UUID: RemoteChild] = [:]
    private(set) var logs: [UUID: RemoteLogEvent] = [:]
    private(set) var routineSteps: [UUID: RemoteRoutineStep] = [:]
    private(set) var carePlans: [UUID: RemoteCarePlan] = [:]
    private(set) var planItems: [UUID: RemotePlanItem] = [:]
    private(set) var visits: [UUID: RemoteVisit] = [:]
    private(set) var foods: [UUID: RemoteFood] = [:]
    private(set) var products: [UUID: RemoteProduct] = [:]
    private(set) var households: Set<UUID> = []
    private var memberHousehold: UUID?
    var members = 1
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

    func upsert(routineSteps rows: [RemoteRoutineStep]) async throws {
        try check()
        for var row in rows where isNewer(row.updatedAt, than: routineSteps[row.id]?.updatedAt) {
            row.serverUpdatedAt = tick()
            routineSteps[row.id] = row
        }
    }

    func upsert(carePlans rows: [RemoteCarePlan]) async throws {
        try check()
        for var row in rows where isNewer(row.updatedAt, than: carePlans[row.id]?.updatedAt) {
            // Same rule as the database: drafts are refused.
            guard row.status != "draft" else { throw Offline() }
            row.serverUpdatedAt = tick()
            carePlans[row.id] = row
        }
    }

    func upsert(planItems rows: [RemotePlanItem]) async throws {
        try check()
        for var row in rows where isNewer(row.updatedAt, than: planItems[row.id]?.updatedAt) {
            row.serverUpdatedAt = tick()
            planItems[row.id] = row
        }
    }

    func upsert(visits rows: [RemoteVisit]) async throws {
        try check()
        for var row in rows where isNewer(row.updatedAt, than: visits[row.id]?.updatedAt) {
            row.serverUpdatedAt = tick()
            visits[row.id] = row
        }
    }

    func upsert(foods rows: [RemoteFood]) async throws {
        try check()
        for var row in rows where isNewer(row.updatedAt, than: foods[row.id]?.updatedAt) {
            row.serverUpdatedAt = tick()
            foods[row.id] = row
        }
    }

    func upsert(products rows: [RemoteProduct]) async throws {
        try check()
        for var row in rows where isNewer(row.updatedAt, than: products[row.id]?.updatedAt) {
            row.serverUpdatedAt = tick()
            products[row.id] = row
        }
    }

    /// A plan item written by another phone.
    func insert(planItem row: RemotePlanItem) {
        var row = row
        row.serverUpdatedAt = tick()
        planItems[row.id] = row
    }

    /// A step written by another phone.
    func insert(step row: RemoteRoutineStep) {
        var row = row
        row.serverUpdatedAt = tick()
        routineSteps[row.id] = row
    }

    func setMembers(_ count: Int) { members = count }

    func memberCount(household: UUID) async throws -> Int {
        try check()
        return members
    }

    func changes(household: UUID, since: Date?) async throws -> RemoteChanges {
        try check()
        let after = since ?? .distantPast
        return RemoteChanges(
            children: children.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after },
            logs: logs.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after },
            routineSteps: routineSteps.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after },
            carePlans: carePlans.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after },
            planItems: planItems.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after },
            visits: visits.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after },
            foods: foods.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after },
            products: products.values.filter { $0.householdID == household && $0.serverUpdatedAt! > after }
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

import Foundation

/// The server side of sync. The app talks to Supabase; tests use a fake.
public protocol SyncRemote: Sendable {
    /// The signed-in person's household, if they're in one.
    func householdID() async throws -> UUID?
    /// Makes a household with the signed-in person as its owner.
    func createHousehold(id: UUID, name: String, memberID: UUID, displayName: String) async throws
    /// Inserts or updates by id. The server keeps whichever has the newer updated_at.
    func upsert(children: [RemoteChild]) async throws
    func upsert(logs: [RemoteLogEvent]) async throws
    /// Rows whose server_updated_at is after `since` (everything when nil).
    func changes(household: UUID, since: Date?) async throws -> RemoteChanges
}

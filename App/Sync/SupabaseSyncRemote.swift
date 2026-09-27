import Core
import Foundation
import Supabase

/// Sync over Supabase's REST API, as the signed-in person. RLS decides what
/// they can see and change (supabase/README.md).
struct SupabaseSyncRemote: SyncRemote {
    let client: SupabaseClient

    /// PostgREST returns at most 1000 rows per request; pull pages through.
    private static let pageSize = 1000

    func householdID() async throws -> UUID? {
        guard let userID = client.auth.currentUser?.id else { return nil }
        struct Membership: Decodable {
            let householdID: UUID
            enum CodingKeys: String, CodingKey { case householdID = "household_id" }
        }
        let rows: [Membership] = try await client.from("household_members")
            .select("household_id")
            .eq("user_id", value: userID)
            .is("deleted_at", value: nil)
            .order("created_at")
            .limit(1)
            .execute()
            .value
        return rows.first?.householdID
    }

    func createHousehold(id: UUID, name: String, memberID: UUID, displayName: String) async throws {
        struct Params: Encodable {
            let household_id: UUID
            let household_name: String
            let member_id: UUID
            let display_name: String
        }
        try await client
            .rpc("create_household", params: Params(
                household_id: id, household_name: name, member_id: memberID, display_name: displayName
            ))
            .execute()
    }

    func upsert(children: [RemoteChild]) async throws {
        guard !children.isEmpty else { return }
        try await client.from("children").upsert(children, onConflict: "id", returning: .minimal).execute()
    }

    func upsert(logs: [RemoteLogEvent]) async throws {
        guard !logs.isEmpty else { return }
        try await client.from("log_events").upsert(logs, onConflict: "id", returning: .minimal).execute()
    }

    func changes(household: UUID, since: Date?) async throws -> RemoteChanges {
        RemoteChanges(
            children: try await pages(of: "children", household: household, since: since),
            logs: try await pages(of: "log_events", household: household, since: since)
        )
    }

    private func pages<Row: Decodable & Sendable>(of table: String, household: UUID, since: Date?) async throws -> [Row] {
        var rows: [Row] = []
        while true {
            var query = client.from(table).select().eq("household_id", value: household)
            if let since { query = query.gt("server_updated_at", value: since) }
            let page: [Row] = try await query
                .order("server_updated_at")
                .order("id")
                .range(from: rows.count, to: rows.count + Self.pageSize - 1)
                .execute()
                .value
            rows += page
            if page.count < Self.pageSize { return rows }
        }
    }
}

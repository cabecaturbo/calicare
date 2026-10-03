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
            // The household joined most recently, e.g. a partner's after accepting an invite.
            .order("created_at", ascending: false)
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

    func upsert(routineSteps: [RemoteRoutineStep]) async throws {
        guard !routineSteps.isEmpty else { return }
        try await client.from("routine_steps").upsert(routineSteps, onConflict: "id", returning: .minimal).execute()
    }

    func upsert(carePlans: [RemoteCarePlan]) async throws {
        guard !carePlans.isEmpty else { return }
        try await client.from("care_plans").upsert(carePlans, onConflict: "id", returning: .minimal).execute()
    }

    func upsert(planItems: [RemotePlanItem]) async throws {
        guard !planItems.isEmpty else { return }
        try await client.from("plan_items").upsert(planItems, onConflict: "id", returning: .minimal).execute()
    }

    func upsert(visits: [RemoteVisit]) async throws {
        guard !visits.isEmpty else { return }
        try await client.from("visits").upsert(visits, onConflict: "id", returning: .minimal).execute()
    }

    func upsert(foods: [RemoteFood]) async throws {
        guard !foods.isEmpty else { return }
        try await client.from("foods").upsert(foods, onConflict: "id", returning: .minimal).execute()
    }

    func upsert(products: [RemoteProduct]) async throws {
        guard !products.isEmpty else { return }
        try await client.from("products").upsert(products, onConflict: "id", returning: .minimal).execute()
    }

    func memberCount(household: UUID) async throws -> Int {
        try await client.from("household_members")
            .select("id", head: true, count: .exact)
            .eq("household_id", value: household)
            .is("deleted_at", value: nil)
            .execute()
            .count ?? 1
    }

    func changes(household: UUID, since: Date?) async throws -> RemoteChanges {
        RemoteChanges(
            children: try await pages(of: "children", household: household, since: since),
            logs: try await pages(of: "log_events", household: household, since: since),
            routineSteps: try await pages(of: "routine_steps", household: household, since: since),
            carePlans: try await pages(of: "care_plans", household: household, since: since),
            planItems: try await pages(of: "plan_items", household: household, since: since),
            visits: try await pages(of: "visits", household: household, since: since),
            foods: try await pages(of: "foods", household: household, since: since),
            products: try await pages(of: "products", household: household, since: since)
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

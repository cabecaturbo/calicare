import Core
import Foundation
import Supabase

/// A person in the household, as the members list shows them.
struct HouseholdMember: Identifiable, Decodable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let role: String
    let displayName: String
    let updatedAt: Date

    var isOwner: Bool { role == "owner" }

    enum CodingKeys: String, CodingKey {
        case id, role
        case userID = "user_id"
        case displayName = "display_name"
        case updatedAt = "updated_at"
    }
}

/// A new invite, ready to share.
struct CreatedInvite: Equatable, Sendable {
    let code: InviteCode
    let role: InviteRole
    let expiresAt: Date
}

/// Why joining didn't work, in words a parent can act on.
enum JoinProblem: Error, Equatable {
    case unknownCode, expired, alreadyUsed, other

    var message: String {
        switch self {
        case .unknownCode: "That code doesn't match an invite. Check the letters and try again."
        case .expired: "That code has expired. Ask for a new one; they last a week."
        case .alreadyUsed: "That code has already been used. Each code works once, so ask for a new one."
        case .other: "Couldn't join just now. Check your connection and try again."
        }
    }
}

/// Invites and members, as the signed-in person. The rules live in the
/// database (supabase/migrations): only owners invite or remove; codes work
/// once and expire after 7 days.
struct HouseholdService {
    let client: SupabaseClient
    let household: UUID

    func createInvite(_ role: InviteRole) async throws -> CreatedInvite {
        struct Params: Encodable {
            let target_household: UUID
            let invite_role: String
        }
        struct Row: Decodable {
            let code: String
            let expires_at: Date
        }
        let rows: [Row] = try await client
            .rpc("create_invite", params: Params(target_household: household, invite_role: role.memberRole))
            .execute()
            .value
        guard let row = rows.first, let code = InviteCode(row.code) else { throw JoinProblem.other }
        return CreatedInvite(code: code, role: role, expiresAt: row.expires_at)
    }

    func members() async throws -> [HouseholdMember] {
        try await client.from("household_members")
            .select("id, user_id, role, display_name, updated_at")
            .eq("household_id", value: household)
            .is("deleted_at", value: nil)
            .order("created_at")
            .execute()
            .value
    }

    /// Owners remove others; anyone can remove themselves (leave). Soft delete.
    func remove(_ member: HouseholdMember) async throws {
        struct Change: Encodable {
            let deleted_at: Date
            let updated_at: Date
        }
        let now = max(Date.now, member.updatedAt.addingTimeInterval(0.001))
        try await client.from("household_members")
            .update(Change(deleted_at: now, updated_at: now), returning: .minimal)
            .eq("id", value: member.id)
            .execute()
    }
}

/// Joining needs no household yet, so it stands alone.
enum HouseholdJoin {
    static func accept(_ code: InviteCode, displayName: String, client: SupabaseClient) async throws -> UUID {
        struct Params: Encodable {
            let invite_code: String
            let member_id: UUID
            let display_name: String
        }
        do {
            return try await client
                .rpc("accept_invite", params: Params(invite_code: code.value, member_id: UUID(), display_name: displayName))
                .execute()
                .value
        } catch let error as PostgrestError {
            switch error.code {
            case "CC001": throw JoinProblem.unknownCode
            case "CC002": throw JoinProblem.expired
            case "CC003": throw JoinProblem.alreadyUsed
            default: throw JoinProblem.other
            }
        } catch {
            throw JoinProblem.other
        }
    }
}

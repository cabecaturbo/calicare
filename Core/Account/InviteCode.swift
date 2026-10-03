import Foundation

/// A 6-character household invite code, as typed or read aloud.
public struct InviteCode: Equatable, Sendable, CustomStringConvertible {
    /// No 0/O or 1/I, matching the server.
    public static let alphabet = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    public static let length = 6

    public let value: String

    /// Accepts "abc 234", "ABC-234", or "abc234". Nil if it can't be a code.
    public init?(_ typed: String) {
        let cleaned = typed.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == Self.length, cleaned.allSatisfy(Self.alphabet.contains) else { return nil }
        value = cleaned
    }

    /// "ABC 234": easier to read and say.
    public var description: String {
        "\(value.prefix(3)) \(value.suffix(3))"
    }

    /// What goes in the share sheet.
    public func shareMessage(childName: String?, role: InviteRole, expires: Date, locale: Locale = .current) -> String {
        let who = childName.map { "\($0)'s" } ?? "our"
        let what = role == .partner ? "log \(who) day together" : "help log \(who) day"
        let date = expires.formatted(.dateTime.month(.abbreviated).day().locale(locale))
        return "Join me on Cali Care to \(what). Open Cali Care, go to Settings → Household → Join with a code, and enter \(description). It works once and expires \(date)."
    }
}

/// Who an invite is for.
public enum InviteRole: String, Sendable, CaseIterable, Identifiable {
    /// Joins as an owner: can do everything.
    case partner
    /// Can log and edit logs, but can't remove children or members.
    case caregiver

    public var id: String { rawValue }

    /// The server's member_role.
    public var memberRole: String { self == .partner ? "owner" : "caregiver" }
}

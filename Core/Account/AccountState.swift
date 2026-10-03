import Foundation

/// The optional account. Everything works in every state; an account only
/// adds sharing with a partner or caregiver.
public enum AccountState: Equatable, Sendable {
    /// No account. The app works exactly as before.
    case signedOut
    case signedIn(AccountInfo)
    /// Was signed in, but the session couldn't be renewed. Logs stay on the
    /// phone; signing in again resumes sharing.
    case expired(AccountInfo)

    public var info: AccountInfo? {
        switch self {
        case .signedOut: nil
        case .signedIn(let info), .expired(let info): info
        }
    }

    /// Signed in but hasn't said what others should see yet.
    public var needsDisplayName: Bool {
        if case .signedIn(let info) = self { return info.displayName == nil }
        return false
    }
}

public struct AccountInfo: Equatable, Sendable {
    public let userID: UUID
    /// What others see: "Mom", "Dad", "Grandma". Nil until chosen.
    public let displayName: String?

    public init(userID: UUID, displayName: String?) {
        self.userID = userID
        self.displayName = displayName.flatMap(DisplayName.clean)
    }
}

/// Just the parts of a stored session the account state needs.
public struct SessionSnapshot: Equatable, Sendable {
    public let userID: UUID
    public let expiresAt: Date
    /// True after renewing the session failed for a reason other than being offline.
    public let refreshFailed: Bool

    public init(userID: UUID, expiresAt: Date, refreshFailed: Bool = false) {
        self.userID = userID
        self.expiresAt = expiresAt
        self.refreshFailed = refreshFailed
    }
}

extension AccountState {
    /// An access token that has run out is normal; it renews on its own.
    /// Only a session that is past its expiry *and* couldn't be renewed counts
    /// as expired, so being offline never signs anyone out.
    public static func resolve(session: SessionSnapshot?, displayName: String?, now: Date = .now) -> AccountState {
        guard let session else { return .signedOut }
        let info = AccountInfo(userID: session.userID, displayName: displayName)
        if session.refreshFailed, session.expiresAt <= now {
            return .expired(info)
        }
        return .signedIn(info)
    }
}

/// Rules for the name others see.
public enum DisplayName {
    public static let maxLength = 40

    /// Trimmed, or nil if empty. Longer names are cut to fit.
    public static func clean(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}

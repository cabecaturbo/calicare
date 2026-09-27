import Foundation

/// Who logged something: the person's display name when signed in, "You"
/// when not. Shown as "by Dad" only when more than one person shares the
/// household; alone, a name next to every log is just noise.
public enum LoggedBy {
    /// Saved on logs made without an account.
    public static let unsignedName = "You"
    /// What logs said before prompt 2.5.
    static let legacyNames: Set<String> = ["You", "Me"]

    /// The name to save on a new log.
    public static func current(settings: AccountSettings = AccountSettings()) -> String {
        settings.displayName ?? unsignedName
    }

    /// True for logs this phone's person made: their name, or a pre-account "You".
    public static func isMine(_ loggedBy: String, myName: String?) -> Bool {
        legacyNames.contains(loggedBy) || loggedBy == myName
    }

    /// "by Dad", "by you", or nil when the household is just one person.
    public static func byline(_ loggedBy: String, myName: String?, householdSize: Int) -> String? {
        guard householdSize > 1, !loggedBy.isEmpty else { return nil }
        return isMine(loggedBy, myName: myName) ? "by you" : "by \(loggedBy)"
    }
}

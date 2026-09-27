import Foundation

/// Where sync is up to, in the App Group: which account and household this
/// phone syncs with, the "changes since" cursor, and when it last finished.
public struct SyncSettings: Sendable {
    private let suiteName: String?

    public init(suiteName: String? = AppGroup.identifier) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var userID: UUID? {
        get { defaults.string(forKey: "sync.userID").flatMap(UUID.init(uuidString:)) }
        nonmutating set { defaults.set(newValue?.uuidString, forKey: "sync.userID") }
    }

    public var householdID: UUID? {
        get { defaults.string(forKey: "sync.householdID").flatMap(UUID.init(uuidString:)) }
        nonmutating set { defaults.set(newValue?.uuidString, forKey: "sync.householdID") }
    }

    /// The newest server_updated_at already pulled.
    public var cursor: Date? {
        get { defaults.object(forKey: "sync.cursor") as? Date }
        nonmutating set { defaults.set(newValue, forKey: "sync.cursor") }
    }

    /// People in the household, as of the last sync. 1 when not syncing.
    public var householdSize: Int {
        get { max(defaults.integer(forKey: "sync.householdSize"), 1) }
        nonmutating set { defaults.set(newValue, forKey: "sync.householdSize") }
    }

    public var lastSyncedAt: Date? {
        get { defaults.object(forKey: "sync.lastSyncedAt") as? Date }
        nonmutating set { defaults.set(newValue, forKey: "sync.lastSyncedAt") }
    }

    /// Forgets the account and household (after signing out). Local data stays.
    public func reset() {
        userID = nil
        householdID = nil
        cursor = nil
        lastSyncedAt = nil
        householdSize = 1
    }
}

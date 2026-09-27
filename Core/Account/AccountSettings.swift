import Foundation

/// The signed-in person's display name, kept in the App Group so widgets and
/// intents can show "by Dad" later (prompt 2.5). Nil when signed out.
public struct AccountSettings {
    private let defaults: UserDefaults
    private static let displayNameKey = "account.displayName"

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public var displayName: String? {
        get { defaults.string(forKey: Self.displayNameKey).flatMap(DisplayName.clean) }
        nonmutating set { defaults.set(newValue.flatMap(DisplayName.clean), forKey: Self.displayNameKey) }
    }
}

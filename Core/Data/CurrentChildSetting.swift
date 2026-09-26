import Foundation

/// Which child one-tap logs go to, shared across the app, widgets, and intents.
public struct CurrentChildSetting: @unchecked Sendable {
    // UserDefaults is thread-safe; @unchecked covers SDKs where it isn't marked Sendable.
    private let defaults: UserDefaults
    static let key = "currentChildID"

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public var childID: UUID? {
        get { defaults.string(forKey: Self.key).flatMap(UUID.init(uuidString:)) }
        nonmutating set {
            if let newValue {
                defaults.set(newValue.uuidString, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}

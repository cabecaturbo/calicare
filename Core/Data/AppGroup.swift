import Foundation

/// The App Group shared by the app, widgets, and intents.
public enum AppGroup {
    public static let identifier = "group.com.cursorkittens.calicare"

    /// Shared defaults. Falls back to `.standard` if the group is missing
    /// (e.g. an unsigned test host), so callers never crash.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

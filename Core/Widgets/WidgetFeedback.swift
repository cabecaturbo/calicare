import Foundation

/// A widget tap that just logged something. Widgets show "Logged" with Undo
/// for about a minute, while the log is still there.
public struct WidgetFeedback: Codable, Hashable, Sendable {
    public static let duration: TimeInterval = 60

    public let logID: UUID
    public let childID: UUID
    /// E.g. "Itchy spell".
    public let title: String
    public let loggedAt: Date

    public init(logID: UUID, childID: UUID, title: String, loggedAt: Date) {
        self.logID = logID
        self.childID = childID
        self.title = title
        self.loggedAt = loggedAt
    }

    public var expiresAt: Date {
        loggedAt.addingTimeInterval(Self.duration)
    }

    public func isShowing(at date: Date) -> Bool {
        date < expiresAt
    }
}

/// The last widget tap, shared between the widget extension and the app.
public struct WidgetFeedbackStore: @unchecked Sendable {
    // UserDefaults is thread-safe; @unchecked covers SDKs where it isn't marked Sendable.
    private let defaults: UserDefaults
    static let key = "widgetFeedback"

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    public var latest: WidgetFeedback? {
        get {
            defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(WidgetFeedback.self, from: $0) }
        }
        nonmutating set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}

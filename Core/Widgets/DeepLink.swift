import Foundation

/// Links from widgets into the app (scheme registered in project.yml).
public enum DeepLink {
    public static let scheme = "calicare"

    /// Opens the note sheet: a widget can't take typing.
    public static let note: URL = {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "note"
        return parts.url ?? URL(fileURLWithPath: "/")
    }()

    public static func isNote(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == "note"
    }

    /// Opens Progress (the Night strip widget).
    public static let progress: URL = {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "progress"
        return parts.url ?? URL(fileURLWithPath: "/")
    }()

    public static func isProgress(_ url: URL) -> Bool {
        url.scheme == scheme && url.host == "progress"
    }

    /// Puts Quick Log on the Lock Screen (the reminder, and the card when it ended early).
    public static let quickLog: URL = link("quicklog")

    /// Last night's summary with Share (the Quick Log card in the morning).
    public static let night: URL = link("night")

    public static func isQuickLog(_ url: URL) -> Bool { url.scheme == scheme && url.host == "quicklog" }
    public static func isNight(_ url: URL) -> Bool { url.scheme == scheme && url.host == "night" }

    private static func link(_ host: String) -> URL {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = host
        return parts.url ?? URL(fileURLWithPath: "/")
    }
}

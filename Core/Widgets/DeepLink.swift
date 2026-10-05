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

    /// Starts Tonight (the bedtime reminder, and the Tonight card when it ended early).
    public static let tonight: URL = link("tonight")

    /// Last night's summary with Share (the Tonight card in the morning).
    public static let night: URL = link("night")

    public static func isTonight(_ url: URL) -> Bool { url.scheme == scheme && url.host == "tonight" }
    public static func isNight(_ url: URL) -> Bool { url.scheme == scheme && url.host == "night" }

    private static func link(_ host: String) -> URL {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = host
        return parts.url ?? URL(fileURLWithPath: "/")
    }
}

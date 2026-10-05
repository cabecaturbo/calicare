import Foundation
import os

/// What happens when a log is tapped from the Lock Screen (the widget circle or
/// a Live Activity): to the unified log, and the last 40 lines into the App
/// Group so Settings › Debug can show them on the phone.
public enum LockScreenDiagnostics {
    public static let logger = Logger(subsystem: "com.cursorkittens.calicare", category: "lockscreen")
    private static let key = "diagnostics.lockscreen"
    private static let limit = 40

    public struct Line: Codable, Sendable, Identifiable, Equatable {
        public let id: UUID
        public let at: Date
        public let process: String
        public let message: String
    }

    /// Records one line, tagged with the process it ran in (app or widgets).
    public static func note(_ message: String) {
        let process = Bundle.main.bundleIdentifier?.hasSuffix(".widgets") == true ? "widgets" : "app"
        logger.notice("\(process, privacy: .public): \(message, privacy: .public)")
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        var lines = recent(defaults)
        lines.append(Line(id: UUID(), at: .now, process: process, message: message))
        if let data = try? JSONEncoder().encode(lines.suffix(limit)) {
            defaults?.set(data, forKey: key)
        }
    }

    /// Newest last.
    public static func recent(_ defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) -> [Line] {
        guard let data = defaults?.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Line].self, from: data)) ?? []
    }

    public static func clear() {
        UserDefaults(suiteName: AppGroup.identifier)?.removeObject(forKey: key)
    }

    /// Whether files under first-unlock protection can be read right now.
    /// False only before the first unlock after a restart.
    public static var protectedDataAvailable: Bool {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            return false
        }
        let probe = url.appendingPathComponent(".lockscreen-probe")
        do {
            try Data("ok".utf8).write(to: probe, options: .atomic)
            _ = try Data(contentsOf: probe)
            return true
        } catch {
            return false
        }
    }
}

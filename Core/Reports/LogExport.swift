import Foundation

/// "Your data": every log as CSV, one row per log, oldest first. Opens in
/// Numbers, Excel, and Google Sheets. Plain words, no internal codes.
public enum LogExport {
    public static let header = ["Child", "Date", "Time", "What", "Value", "Where", "Note", "Logged from", "Logged by"]

    /// `children` names each row; logs for children not listed (removed) say "Removed child".
    public static func csv(
        _ entries: [LogEntry],
        children: [ChildInfo],
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> String {
        let names = Dictionary(children.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let date = formatter("yyyy-MM-dd", calendar: calendar, locale: locale)
        let time = formatter("HH:mm", calendar: calendar, locale: locale)
        let rows = entries.sorted { $0.timestamp < $1.timestamp }.map { entry in
            [
                entry.childID.flatMap { names[$0] } ?? "Removed child",
                date.string(from: entry.timestamp),
                time.string(from: entry.timestamp),
                what(entry.type),
                entry.value.map(words) ?? "",
                entry.bodyAreas.map(\.words).joined(separator: "; "),
                entry.note ?? "",
                source(entry.source),
                entry.loggedBy,
            ]
        }
        return ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Writes the CSV to a temporary file named for today, for the share sheet.
    public static func file(_ csv: String, now: Date = .now) throws -> URL {
        let stamp = now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Cali Care logs \(stamp).csv")
        try Data(csv.utf8).write(to: url, options: .atomic)
        return url
    }

    static func what(_ type: LogType) -> String {
        switch type {
        case .nightRating: "Night"
        case .itchEpisode: "Itchy"
        case .flare: "Flare"
        case .bowelMovement: "Bowel movement"
        case .mood: "Mood"
        case .routineDone: "Routine"
        case .note: "Note"
        case .skinToday: "Skin today"
        case .bath: "Bath"
        case .patchTest: "Patch test"
        case .supplement: "Supplement"
        case .providerMessage: "Message to provider"
        case .foodTrial: "Food trial"
        }
    }

    static func words(_ value: LogValue) -> String {
        switch value {
        case .skin(let answer): answer.words
        case .patch(let result): result.title.lowercased()
        case .bowel(.none): "none"
        default: value.rawValue
        }
    }

    static func source(_ source: EntrySource) -> String {
        switch source {
        case .widget: "Widget"
        case .intent: "Siri or Shortcuts"
        case .notification: "Notification"
        case .app: "App"
        case .watch: "Watch"
        }
    }

    /// Quotes a field when it has a comma, quote, or line break. A leading
    /// =, +, -, or @ gets an apostrophe so spreadsheets don't run it as a formula.
    static func escape(_ field: String) -> String {
        var text = field
        if let first = text.first, "=+-@".contains(first) { text = "'" + text }
        guard text.contains(where: { ",\"\n\r".contains($0) }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func formatter(_ format: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }
}

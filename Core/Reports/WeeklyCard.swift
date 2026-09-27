import Foundation

/// What a weekly card shows, as plain values. Small enough to travel inside a
/// Messages link, so the full card can be drawn on any phone, offline, without
/// the family's logs.
public struct WeeklyCard: Codable, Equatable, Sendable {
    public struct Day: Codable, Equatable, Sendable {
        public var letter: String
        /// CareLevel raw values; nil when nothing was logged.
        public var night: Int?
        public var skin: Int?

        enum CodingKeys: String, CodingKey { case letter = "l", night = "n", skin = "s" }
    }

    public var childName: String
    public var dateRange: String
    public var headline: String
    public var hasSummary: Bool
    public var days: [Day]
    public var goodNights: Int
    public var itchyWakeUps: Int
    public var itchyWakeUpsLastWeek: Int?
    public var routineDays: Int
    public var daysWithLogs: Int
    public var bowelMovements: Int
    public var usualMood: String?
    public var worthWatching: String?

    // Short keys keep the Messages link small.
    enum CodingKeys: String, CodingKey {
        case childName = "c", dateRange = "r", headline = "h", hasSummary = "hs", days = "d"
        case goodNights = "g", itchyWakeUps = "i", itchyWakeUpsLastWeek = "il", routineDays = "rd"
        case daysWithLogs = "dl", bowelMovements = "b", usualMood = "m", worthWatching = "w"
    }

    public init(report: WeeklyReport, calendar: Calendar = .autoupdatingCurrent) {
        let letters = Date.FormatStyle(calendar: calendar).weekday(.narrow)
        childName = report.child.name
        dateRange = report.dateRange(calendar: calendar)
        headline = report.headline.text
        hasSummary = report.headline != .notEnoughLogs
        days = report.days.map {
            Day(letter: $0.day.noon(calendar: calendar).formatted(letters), night: $0.night?.rawValue, skin: $0.skin?.rawValue)
        }
        goodNights = report.goodNights
        itchyWakeUps = report.itchyWakeUps
        itchyWakeUpsLastWeek = report.itchyWakeUpsLastWeek
        routineDays = report.routineDays
        daysWithLogs = report.daysWithLogs
        bowelMovements = report.bowelMovements
        usualMood = report.usualMood?.rawValue.capitalized
        worthWatching = report.worthWatching
    }

    // MARK: - Messages link

    static let scheme = "calicare"

    /// calicare://week?v=1&card=<base64url JSON>
    public var url: URL? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        var parts = URLComponents()
        parts.scheme = Self.scheme
        parts.host = "week"
        parts.queryItems = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "card", value: Self.base64URL(data))]
        return parts.url
    }

    public init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == Self.scheme, parts.host == "week",
              let encoded = parts.queryItems?.first(where: { $0.name == "card" })?.value,
              let data = Self.data(base64URL: encoded),
              let card = try? JSONDecoder().decode(WeeklyCard.self, from: data)
        else { return nil }
        self = card
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func data(base64URL string: String) -> Data? {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}

import Foundation

/// A cooked batch (prompt 5.5): what it is, fridge or freezer, and the days
/// the parent chose to keep it. Nothing is suggested about food safety.
public struct LeftoverBatch: Equatable, Sendable, Identifiable {
    public let entry: LogEntry
    public let name: String
    public let place: BatchPlace
    public let days: Int
    public var id: UUID { entry.id }

    public init?(_ entry: LogEntry) {
        guard entry.type == .batch, case .batch(let place)? = entry.value else { return nil }
        let (name, days) = Self.parse(entry.note)
        self.entry = entry
        self.name = name
        self.place = place
        self.days = days
    }

    /// The batches still in the fridge or freezer, soonest first.
    public static func current(from logs: [LogEntry]) -> [LeftoverBatch] {
        logs.compactMap(LeftoverBatch.init).filter { $0.place != .done }.sorted { $0.useBy < $1.useBy }
    }

    /// "Chicken rice · 3 days"
    public static func note(name: String, days: Int) -> String {
        "\(name.trimmingCharacters(in: .whitespacesAndNewlines)) · \(days == 1 ? "1 day" : "\(days) days")"
    }

    static func parse(_ note: String?) -> (name: String, days: Int) {
        let parts = (note ?? "").components(separatedBy: " · ")
        let days = parts.count > 1 ? parts[1].split(separator: " ").first.flatMap { Int($0) } ?? 1 : 1
        return (parts.first ?? "Batch", max(days, 1))
    }

    /// When the parent's chosen days run out.
    public var useBy: Date { entry.timestamp.addingTimeInterval(TimeInterval(days) * 86_400) }

    public func daysLeft(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: useBy)).day ?? 0
    }
}

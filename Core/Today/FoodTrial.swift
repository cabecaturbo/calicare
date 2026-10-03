import Foundation

/// A food trial (prompt 5.2): the schedule the plan or parent set (days, and
/// optional amounts per day), what was given, anything worth watching, and the
/// days to look at skin and nights (one more day, because reactions can show
/// up 12–24 hours later). The parent decides how it ends.
public struct FoodTrial: Equatable, Sendable, Identifiable {
    public let food: FoodInfo
    public let started: Date
    public let days: Int
    /// "1 tsp", "1 tbsp", … one per day; may be empty.
    public let steps: [String]
    public let given: [Date]
    public let worthWatching: [LogEntry]
    public let ended: Date?
    public var id: UUID { food.id }

    /// The latest trial for each food, from that child's trial logs.
    public static func trials(foods: [FoodInfo], logs: [LogEntry]) -> [FoodTrial] {
        foods.compactMap { food in
            let mine = logs.filter { $0.type == .foodTrial && $0.routineStepID == food.id }.sorted { $0.timestamp < $1.timestamp }
            guard let start = mine.last(where: { $0.value == .trial(.started) }) else { return nil }
            let after = mine.filter { $0.timestamp >= start.timestamp }
            let (days, steps) = schedule(start.note)
            return FoodTrial(
                food: food, started: start.timestamp, days: days, steps: steps,
                given: after.filter { $0.value == .trial(.given) }.map(\.timestamp),
                worthWatching: after.filter { $0.value == .trial(.worthWatching) },
                ended: after.last(where: { $0.value == .trial(.ended) })?.timestamp
            )
        }
    }

    /// "4 days · 1 tsp, 1 tbsp" → (4, ["1 tsp", "1 tbsp"]).
    public static func schedule(_ note: String?) -> (days: Int, steps: [String]) {
        let parts = (note ?? "").components(separatedBy: " · ")
        let days = parts.first.flatMap { $0.split(separator: " ").first }.flatMap { Int($0) } ?? 1
        let steps = parts.count > 1 ? parts[1].components(separatedBy: ", ").filter { !$0.isEmpty } : []
        return (max(days, 1), steps)
    }

    public static func note(days: Int, steps: [String]) -> String {
        let clean = steps.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let head = days == 1 ? "1 day" : "\(days) days"
        return clean.isEmpty ? head : "\(head) · \(clean.joined(separator: ", "))"
    }

    public var isRunning: Bool { ended == nil }

    /// Day 1, 2, … of the trial at `now` (past the last day once it's over).
    public func day(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        (calendar.dateComponents([.day], from: calendar.startOfDay(for: started), to: calendar.startOfDay(for: now)).day ?? 0) + 1
    }

    /// Today's amount from the schedule, if it lists one for this day.
    public func step(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> String? {
        let index = day(at: now, calendar: calendar) - 1
        return steps.indices.contains(index) ? steps[index] : nil
    }

    public func givenToday(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        given.contains { calendar.isDate($0, inSameDayAs: now) }
    }

    /// The trial's days plus one more, for skin and nights.
    public func watchDays(calendar: Calendar = .autoupdatingCurrent) -> [CareDay] {
        let first = CareDay.containing(started, calendar: calendar)
        return (0...days).map { first.adding(days: $0, calendar: calendar) }
    }
}

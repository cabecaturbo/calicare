import Foundation

/// The rotation planner and plant counter (prompt 5.3). Both follow the plan's
/// own words ("4-day rotation by food family", "40–50 plants/week") and only
/// use foods already on the safe list. Nothing is suggested or added.
public enum FoodRotation {
    /// Families that aren't plants, for the plant counter.
    public static let animalFamilies: Set<String> = ["Poultry", "Bovine", "Fish", "Pork", "Lamb and goat"]

    /// "4-day rotation" → 4.
    public static func days(in items: [PlanItemInfo]) -> Int? {
        for item in items where item.kind == .foodRule {
            if let match = item.text.lowercased().firstMatch(of: /(\d+)\s*-?\s*day\s+rotation/), let days = Int(match.1) {
                return days
            }
        }
        return nil
    }

    /// "40–50 plants/week" → 40...50; "30 plants a week" → 30...30.
    public static func plantGoal(in items: [PlanItemInfo]) -> ClosedRange<Int>? {
        for item in items where item.kind == .foodRule {
            let text = item.text.lowercased()
            if let match = text.firstMatch(of: /(\d+)\s*(?:[–-]\s*(\d+)\s*)?plants?/), let low = Int(match.1) {
                let high = match.2.flatMap { Int($0) } ?? low
                return low...max(low, high)
            }
        }
        return nil
    }

    /// Safe foods arranged by family across the rotation's days: each family
    /// lands on one day, families spread evenly, in alphabetical order.
    /// Foods without a family each count as their own family.
    public static func plan(foods: [FoodInfo], days: Int) -> [[(family: String, foods: [String])]] {
        guard days > 0 else { return [] }
        let safe = foods.filter { $0.status == .safe }
        let byFamily = Dictionary(grouping: safe) { $0.family ?? $0.name }
        var schedule = Array(repeating: [(family: String, foods: [String])](), count: days)
        for (index, family) in byFamily.keys.sorted().enumerated() {
            schedule[index % days].append((family, byFamily[family]!.map(\.name).sorted()))
        }
        return schedule
    }

    /// Which rotation day it is (0-based), counting from `start`.
    public static func today(start: Date, days: Int, now: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        guard days > 0 else { return 0 }
        let elapsed = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day ?? 0
        return ((elapsed % days) + days) % days
    }

    /// Different plant foods logged in meals this week (the calendar week).
    public static func plantsThisWeek(meals: [LogEntry], foods: [FoodInfo], now: Date,
                                      calendar: Calendar = .autoupdatingCurrent) -> Set<String> {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let families = Dictionary(foods.map { ($0.name.lowercased(), $0.family) }, uniquingKeysWith: { a, _ in a })
        var plants = Set<String>()
        for meal in meals where meal.type == .meal && meal.timestamp >= weekStart && meal.timestamp <= now {
            for name in (meal.note ?? "").components(separatedBy: ", ") where !name.isEmpty {
                let family = families[name.lowercased()] ?? FoodFamilies.family(for: name)
                if !(family.map(animalFamilies.contains) ?? false) { plants.insert(name.lowercased()) }
            }
        }
        return plants
    }
}

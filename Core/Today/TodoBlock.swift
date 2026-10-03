import Foundation

/// To do's time blocks. Afternoon shows only when it has something in it.
public enum TodoBlock: String, Codable, Sendable, CaseIterable, Comparable {
    case morning, afternoon, bedtime

    public var title: String {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .bedtime: "Bedtime"
        }
    }

    /// The routine steps that belong here. Afternoon has none (steps are morning or evening).
    public var routineTime: RoutineTime? {
        switch self {
        case .morning: .morning
        case .afternoon: nil
        case .bedtime: .evening
        }
    }

    public static func < (a: TodoBlock, b: TodoBlock) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }

    /// When a supplement is given, from how often the plan says: 1x (or
    /// nothing) is morning; 2x is morning and bedtime; 3x adds afternoon.
    public static func defaults(forFrequency frequency: String?) -> [TodoBlock] {
        switch SupplementPlan.perDay(frequency) ?? 1 {
        case ...1: [.morning]
        case 2: [.morning, .bedtime]
        default: [.morning, .afternoon, .bedtime]
        }
    }

    /// "morning,bedtime" → [.morning, .bedtime]. Unknown words are skipped.
    public static func parse(_ raw: String?) -> [TodoBlock]? {
        guard let raw else { return nil }
        return raw.split(separator: ",").compactMap { TodoBlock(rawValue: String($0)) }.sorted()
    }

    public static func raw(_ blocks: [TodoBlock]) -> String {
        Set(blocks).sorted().map(\.rawValue).joined(separator: ",")
    }
}

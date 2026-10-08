import Foundation

/// Plan's star (DESIGN.md "One star per screen"): where you are in the plan
/// and the next visit. "Week 2 of 12" when the parent set a length, else
/// "Week 2". Only stored dates are used.
public struct PlanStar: Equatable, Sendable {
    /// 1-based, capped at the length.
    public let week: Int
    public let lengthWeeks: Int?
    /// Days into the plan, counting today (day 1 is the start day).
    public let day: Int
    /// "Next visit Oct 26, in 3 weeks", or nil when none is scheduled.
    public let nextVisit: String?

    public init(plan: CarePlanInfo, visits: [VisitInfo], now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let start = calendar.startOfDay(for: plan.startedAt ?? now)
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0
        day = max(days, 0) + 1
        var week = max(days, 0) / 7 + 1
        if let length = plan.lengthWeeks { week = min(week, length) }
        self.week = week
        lengthWeeks = plan.lengthWeeks
        nextVisit = visits.filter { $0.date > now }.min { $0.date < $1.date }.map { visit in
            "Next visit \(PlanWords.day(visit.date, calendar: calendar)), \(Self.distance(to: visit.date, from: now, calendar: calendar))"
        }
    }

    /// "Week 2 of 12" / "Week 2"
    public var title: String {
        lengthWeeks.map { "Week \(week) of \($0)" } ?? "Week \(week)"
    }

    /// How far into the plan, by days (today counts), nil without a length.
    /// Day 1 of a 12-week plan already shows a sliver, so the line never looks empty.
    public var progress: Double? {
        guard let length = lengthWeeks, length > 0 else { return nil }
        return min(Double(day) / Double(length * 7), 1)
    }

    /// The plan's longest stated duration in weeks ("3 months" → 13,
    /// "60-90 days" → 13), offered to the parent, never saved for them.
    public static func suggestedWeeks(_ items: [PlanItemInfo]) -> Int? {
        let weeks = items.compactMap { item -> Int? in
            guard let text = (item.duration ?? item.text).lowercased() as String?,
                  let match = text.firstMatch(of: /(\d+)\s*(?:[-–]\s*(\d+)\s*)?(day|week|month)s?/)
            else { return nil }
            let amount = Double(match.2.flatMap { Int($0) } ?? Int(match.1) ?? 0)
            let days: Double = switch match.3 {
            case "day": amount
            case "week": amount * 7
            default: amount * 30.44
            }
            return Int((days / 7).rounded())
        }
        return weeks.filter { (1...104).contains($0) }.max()
    }

    /// "today", "tomorrow", "in 5 days", "in 3 weeks".
    static func distance(to date: Date, from now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ...0: return "today"
        case 1: return "tomorrow"
        case 2...13: return "in \(days) days"
        default:
            let weeks = Int((Double(days) / 7).rounded())
            return "in \(weeks) weeks"
        }
    }
}

/// Plan › Coming up: dated things the plan or the parent set, soonest first.
/// Three sources only: dose steps the parent added, starts the plan's own
/// rules date ("2 weeks after Coptis"), and scheduled visits. Nothing else
/// is ever shown, so no dose, increase, or date is made up.
public struct ComingUp: Equatable, Sendable {
    public struct Item: Equatable, Sendable, Identifiable {
        public let date: Date
        public let text: String
        public let reason: String?
        /// The plan item it's about (nil for a visit).
        public let itemID: UUID?
        public var id: String { "\(date.timeIntervalSince1970)-\(text)" }
    }

    /// Every dated item, soonest first.
    public let all: [Item]

    /// The first three, for the Plan tab.
    public var shown: [Item] { Array(all.prefix(3)) }
    public var hasMore: Bool { all.count > 3 }

    public init(items: [PlanItemInfo], visits: [VisitInfo], supplements: SupplementPlan, now: Date,
                calendar: Calendar = .autoupdatingCurrent) {
        let tomorrow = calendar.startOfDay(for: now).addingTimeInterval(86_400)
        var list: [Item] = []
        for item in items where item.kind == .supplement {
            let name = SupplementDisplay(item).name
            for step in item.doseSteps where step.startDate >= tomorrow {
                list.append(Item(date: step.startDate, text: "\(name) goes to \(step.amount)", reason: nil, itemID: item.id))
            }
        }
        for row in supplements.rows where row.started == nil && row.item.isGiving != true {
            guard let date = row.canStartAfter, date >= tomorrow else { continue }
            list.append(Item(date: date, text: "Start \(SupplementDisplay(row.item).name)", reason: row.startReason, itemID: row.item.id))
        }
        for visit in visits where visit.date > now {
            let who = visit.provider.isEmpty ? "your provider" : visit.provider
            list.append(Item(date: visit.date, text: "Visit with \(who)", reason: nil, itemID: nil))
        }
        all = list.sorted { $0.date < $1.date }
    }
}

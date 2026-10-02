import Foundation

/// "Worse since when?" (Progress): the changes in a child's care, and when
/// skin or nights turn rougher, what changed in the week before. It only
/// notices; it never says something caused anything.
public struct CareChange: Hashable, Sendable, Identifiable {
    public let date: Date
    /// "Started Antimicrobial herb, Brand C"
    public let text: String
    public var id: String { "\(date.timeIntervalSince1970)-\(text)" }

    public init(date: Date, text: String) {
        self.date = date
        self.text = text
    }
}

public enum CareChanges {
    /// Every change, newest first: plans started and ended, supplements
    /// started and stopped, and new things patch-tested.
    public static func list(plans: [CarePlanInfo], items: [UUID: PlanItemInfo], logs: [LogEntry]) -> [CareChange] {
        var changes: [CareChange] = []
        for plan in plans {
            let from = plan.provider.isEmpty ? "the care plan" : "\(plan.provider)’s plan"
            if let started = plan.startedAt { changes.append(CareChange(date: started, text: "Started \(from)")) }
            if let ended = plan.endedAt { changes.append(CareChange(date: ended, text: "Ended \(from)")) }
        }
        for log in logs {
            switch (log.type, log.value) {
            case (.supplement, .supplement(.started)?):
                changes.append(CareChange(date: log.timestamp, text: "Started \(name(log, items))"))
            case (.supplement, .supplement(.stopped)?):
                changes.append(CareChange(date: log.timestamp, text: "Stopped \(name(log, items))"))
            case (.patchTest, _):
                // What was tested, not where: "Patch test: Calendula balm".
                let what = log.note?.components(separatedBy: " · ").first ?? "something new"
                changes.append(CareChange(date: log.timestamp, text: "Patch test: \(what)"))
            default:
                break
            }
        }
        return changes.sorted { $0.date > $1.date }
    }

    private static func name(_ log: LogEntry, _ items: [UUID: PlanItemInfo]) -> String {
        log.routineStepID.flatMap { items[$0]?.text } ?? "a supplement"
    }

    /// The day skin or nights turned rougher, if they clearly did: the last 3
    /// logged days average at least half a level above the 7 logged days
    /// before them. Returns the first of those days that was above that baseline.
    public static func rougherSince(_ days: [WeekDay]) -> CareDay? {
        let scored = days.compactMap { day in level(day).map { (day.day, $0) } }
        guard scored.count >= 6 else { return nil }
        let recent = Array(scored.suffix(3))
        let baseline = Array(scored.dropLast(3).suffix(7))
        let before = baseline.map(\.1).reduce(0, +) / Double(baseline.count)
        let now = recent.map(\.1).reduce(0, +) / Double(recent.count)
        guard now - before >= 0.5 else { return nil }
        return recent.first { $0.1 > before }?.0
    }

    /// The changes in the 7 days up to and including `day`.
    public static func before(_ day: CareDay, in changes: [CareChange], calendar: Calendar = .autoupdatingCurrent) -> [CareChange] {
        let end = day.interval(calendar: calendar).end
        let start = day.adding(days: -7, calendar: calendar).interval(calendar: calendar).start
        return changes.filter { $0.date >= start && $0.date < end }
    }

    /// One number per day on the 0…2 scale: skin (when answered) and night, averaged.
    static func level(_ day: WeekDay) -> Double? {
        let parts = [day.skin.map { Double($0.step - 1) / 2 }, day.night.map { Double($0.rawValue) }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.reduce(0, +) / Double(parts.count)
    }
}

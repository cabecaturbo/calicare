#if DEBUG
import Foundation
import SwiftData

/// Debug builds only: about eight weeks of believable logs for one child, so
/// the app looks like someone has been using it. The same every time (seeded).
/// Every sample log is by "Sample", so it can all be removed again.
public enum SampleData {
    public static let author = "Sample"

    private static let notes = ["Swim class", "Grandma's house", "Long day at daycare", "Early bedtime", "Park after lunch", "Friend's birthday party"]
    private static let areas: [BodyArea] = [.hands, .elbowCreases, .kneeCreases, .neck, .face, .feet]

    /// Adds the logs. Routine steps are added only if the child has none;
    /// returns the IDs of steps it added, so `remove` can take them away too.
    @discardableResult
    public static func fill(
        child childID: UUID,
        container: ModelContainer,
        days: Int = 56,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) async throws -> [UUID] {
        var rng = SeededRandom(seed: 27)
        let logs = LogStore(modelContainer: container, calendar: calendar, now: { now })
        let routine = RoutineStore(modelContainer: container, now: { now })

        var addedSteps: [UUID] = []
        var steps = try await routine.steps(child: childID)
        if steps.isEmpty {
            for (name, time) in [("Wash face", RoutineTime.morning), ("Moisturizer", .morning), ("Bath", .evening), ("Moisturizer", .evening), ("Pajamas", .evening)] {
                let step = try await routine.add(name: name, time: time, child: childID)
                addedSteps.append(step.id)
            }
            steps = try await routine.steps(child: childID)
        }

        let today = calendar.startOfDay(for: now)
        func when(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date? {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  date < now
            else { return nil }
            return date
        }
        func log(_ type: LogType, _ value: LogValue? = nil, note: String? = nil, source: EntrySource = .widget, at date: Date?) async throws -> LogEntry? {
            guard let date else { return nil }
            return try await logs.log(type, value: value, child: childID, source: source, note: note, loggedBy: author, at: date)
        }

        for daysAgo in stride(from: days, through: 0, by: -1) {
            // Rougher five to seven weeks ago, calmer in the last three.
            let mood: Stretch = (35...49).contains(daysAgo) ? .rough : daysAgo < 21 ? .calm : .middle

            // Last night's wake-ups: late evening the day before, or small hours.
            let wakeUps = rng.int(in: mood.wakeUps)
            for index in 0..<wakeUps {
                let late = index == 0 && rng.chance(0.4)
                let date = late ? when(daysAgo + 1, 23, rng.int(in: 5...55)) : when(daysAgo, rng.int(in: 1...4), rng.int(in: 0...59))
                _ = try await log(.itchEpisode, at: date)
            }
            if !rng.chance(0.14) {
                _ = try await log(.nightRating, .night(mood.night(&rng)), source: .notification, at: when(daysAgo, 7, rng.int(in: 0...20)))
            }
            for step in steps where step.time == .morning && rng.chance(0.85) {
                if let date = when(daysAgo, 7, rng.int(in: 30...55)) {
                    _ = try await logs.logRoutineStep(step.id, source: .app, loggedBy: author, at: date)
                }
            }
            if rng.chance(0.8) {
                _ = try await log(.bowelMovement, .bowel(rng.chance(0.8) ? .good : rng.pick([.hard, .loose])), source: .app, at: when(daysAgo, rng.int(in: 8...10), rng.int(in: 0...59)))
            }
            if rng.chance(mood.flareChance), let flare = try await log(.flare, at: when(daysAgo, rng.int(in: 11...17), rng.int(in: 0...59))) {
                if rng.chance(0.7) {
                    try await logs.setBodyAreas([rng.pick(areas), rng.pick(areas)], on: flare.id)
                }
            }
            if rng.chance(0.35) {
                _ = try await log(.mood, .mood(mood.mood(&rng)), source: .app, at: when(daysAgo, rng.int(in: 12...16), rng.int(in: 0...59)))
            }
            if rng.chance(0.12) {
                _ = try await log(.note, note: rng.pick(notes), source: .app, at: when(daysAgo, 17, rng.int(in: 0...40)))
            }
            if !rng.chance(0.12) {
                _ = try await log(.skinToday, .skin(mood.skin(&rng)), source: .notification, at: when(daysAgo, 18, rng.int(in: 25...45)))
            }
            for step in steps where step.time == .evening && rng.chance(0.85) {
                if let date = when(daysAgo, 19, rng.int(in: 30...59)) {
                    _ = try await logs.logRoutineStep(step.id, source: .app, loggedBy: author, at: date)
                }
            }
        }
        return addedSteps
    }

    /// Soft-deletes every sample log and the given steps. Returns how many logs went.
    @discardableResult
    public static func remove(container: ModelContainer, stepIDs: [UUID]) async throws -> Int {
        let logs = LogStore(modelContainer: container)
        let sample = try await logs.allLive().filter { $0.loggedBy == author }
        for entry in sample { try await logs.delete(entry.id) }
        let routine = RoutineStore(modelContainer: container)
        for id in stepIDs { try? await routine.delete(id) }
        return sample.count
    }

    private enum Stretch {
        case rough, middle, calm

        var wakeUps: ClosedRange<Int> {
            switch self {
            case .rough: 1...3
            case .middle: 0...2
            case .calm: 0...1
            }
        }

        var flareChance: Double {
            switch self {
            case .rough: 0.25
            case .middle: 0.12
            case .calm: 0.05
            }
        }

        func night(_ rng: inout SeededRandom) -> NightRating {
            let roll = rng.unit()
            switch self {
            case .rough: return roll < 0.5 ? .rough : roll < 0.9 ? .okay : .good
            case .middle: return roll < 0.2 ? .rough : roll < 0.8 ? .okay : .good
            case .calm: return roll < 0.05 ? .rough : roll < 0.4 ? .okay : .good
            }
        }

        func skin(_ rng: inout SeededRandom) -> SkinToday {
            switch self {
            case .rough: rng.pick([.flaring, .veryRough, .flaring, .littleItchy])
            case .middle: rng.pick([.littleItchy, .flaring, .littleItchy])
            case .calm: rng.pick([.calm, .calm, .littleItchy])
            }
        }

        func mood(_ rng: inout SeededRandom) -> Mood {
            switch self {
            case .rough: rng.pick([.cranky, .okay, .cranky])
            case .middle: rng.pick([.okay, .great, .cranky])
            case .calm: rng.pick([.great, .great, .okay])
            }
        }
    }
}

/// SplitMix64: small, fast, and the same sequence for the same seed.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    mutating func int(in range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() % UInt64(range.count)) }
    mutating func pick<T>(_ items: [T]) -> T { items[int(in: 0...(items.count - 1))] }
}
#endif

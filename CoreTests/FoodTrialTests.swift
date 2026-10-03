import Core
import Foundation
import Testing

/// Food trials: the schedule, days, what was given, and the extra day to watch.
struct FoodTrialTests {
    private let child = UUID()

    private var eggs: FoodInfo {
        FoodInfo(id: UUID(), childID: child, name: "Eggs", family: "Poultry", status: .testing,
                 statusChangedAt: TestTime.date(24, 9), decidedBy: .parent, note: nil)
    }

    @Test func scheduleNotesRoundTrip() {
        #expect(FoodTrial.note(days: 4, steps: ["1 tsp", " 1 tbsp ", ""]) == "4 days · 1 tsp, 1 tbsp")
        #expect(FoodTrial.schedule("4 days · 1 tsp, 1 tbsp") == (4, ["1 tsp", "1 tbsp"]))
        #expect(FoodTrial.schedule("1 day") == (1, []))
        #expect(FoodTrial.schedule(nil) == (1, []))
    }

    @Test func aTrialsDaysStepsAndWatching() {
        let food = eggs
        func log(_ event: FoodTrialEvent, _ day: Int, _ hour: Int, note: String? = nil) -> LogEntry {
            LogEntry(childID: child, type: .foodTrial, value: .trial(event), note: note, timestamp: TestTime.date(day, hour), routineStepID: food.id)
        }
        let logs = [
            log(.started, 24, 9, note: "3 days · 1 tsp, 1 tbsp, 1/4 cup"),
            log(.given, 24, 12), log(.given, 25, 12),
            log(.worthWatching, 26, 7, note: "Red cheeks"),
        ]
        let trial = try! #require(FoodTrial.trials(foods: [food], logs: logs).first)
        #expect(trial.isRunning)
        #expect(trial.day(at: TestTime.date(26, 9), calendar: TestTime.calendar) == 3)
        #expect(trial.step(at: TestTime.date(26, 9), calendar: TestTime.calendar) == "1/4 cup")
        #expect(trial.step(at: TestTime.date(27, 9), calendar: TestTime.calendar) == nil)
        #expect(trial.givenToday(at: TestTime.date(25, 18), calendar: TestTime.calendar))
        #expect(!trial.givenToday(at: TestTime.date(26, 18), calendar: TestTime.calendar))
        #expect(trial.worthWatching.map(\.note) == ["Red cheeks"])
        #expect(trial.watchDays(calendar: TestTime.calendar).count == 4) // 3 days and one more
    }

    @Test func onlyTheLatestTrialCounts() async throws {
        let harness = try await TestHarness(start: TestTime.date(20, 9))
        let food = try await FoodStore(modelContainer: harness.container).add(name: "Eggs", status: .paused, decidedBy: .plan, child: harness.child.id)
        try await harness.logs.logTrial(.started, food: food.id, child: harness.child.id, note: "2 days", source: .app)
        harness.clock.advance(minutes: 60)
        try await harness.logs.logTrial(.ended, food: food.id, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 60 * 24 * 3)
        try await harness.logs.logTrial(.started, food: food.id, child: harness.child.id, note: "4 days", source: .app)

        let trial = try #require(FoodTrial.trials(foods: [food], logs: try await harness.logs.allLive()).first)
        #expect(trial.days == 4)
        #expect(trial.isRunning)
    }
}

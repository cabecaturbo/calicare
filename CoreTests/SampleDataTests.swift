import Core
import Foundation
import Testing

/// The debug "Fill with sample data" button.
struct SampleDataTests {
    @Test func fillsWeeksOfSampleLogsTheSameEveryTime() async throws {
        let first = try await TestHarness(start: TestTime.date(26, 20))
        let steps = try await SampleData.fill(child: first.child.id, container: first.container, now: TestTime.date(26, 20), calendar: TestTime.calendar)
        let logs = try await first.logs.allLive()

        #expect(steps.count == 5)
        #expect(logs.count > 250)
        #expect(logs.allSatisfy { $0.loggedBy == SampleData.author })
        #expect(logs.allSatisfy { $0.timestamp < TestTime.date(26, 20) })
        #expect(Set(logs.map(\.type)).isSuperset(of: [.nightRating, .itchEpisode, .skinToday, .flare, .routineDone, .bowelMovement, .mood, .note]))

        let second = try await TestHarness(start: TestTime.date(26, 20))
        try await SampleData.fill(child: second.child.id, container: second.container, now: TestTime.date(26, 20), calendar: TestTime.calendar)
        #expect(try await second.logs.allLive().count == logs.count)
    }

    @Test func removeTakesOnlySampleLogs() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 20))
        let mine = try await harness.logs.log(.note, child: harness.child.id, source: .app, note: "Real one")
        let steps = try await SampleData.fill(child: harness.child.id, container: harness.container, now: TestTime.date(26, 20), calendar: TestTime.calendar)

        let removed = try await SampleData.remove(container: harness.container, stepIDs: steps)

        #expect(removed > 250)
        #expect(try await harness.logs.allLive().map(\.id) == [mine.id])
        #expect(try await RoutineStore(modelContainer: harness.container).steps(child: harness.child.id).isEmpty)
    }
}

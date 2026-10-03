import Core
import Foundation
import Testing

/// Leftovers: the parent's days, use-by, and what's still in the fridge or freezer.
struct LeftoverBatchTests {
    @Test func batchesAndUseBy() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 18))
        let rice = try await harness.logs.logBatch(" Chicken rice ", place: .fridge, days: 3, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 10)
        let soup = try await harness.logs.logBatch("Soup", place: .freezer, days: 30, child: harness.child.id, source: .app)
        harness.clock.advance(minutes: 10)
        let old = try await harness.logs.logBatch("Old oats", place: .fridge, days: 1, child: harness.child.id, source: .app)
        try await harness.logs.update(old.id, value: .batch(.done), note: old.note, timestamp: old.timestamp)

        let current = LeftoverBatch.current(from: try await harness.logs.allLive())
        #expect(current.map(\.name) == ["Chicken rice", "Soup"])
        #expect(current[0].useBy == TestTime.date(29, 18))
        #expect(current[0].daysLeft(at: TestTime.date(27, 9), calendar: TestTime.calendar) == 2)
        #expect(current[1].place == .freezer)
        #expect(rice.note == "Chicken rice · 3 days")
        #expect(soup.note == "Soup · 30 days")
    }
}

import Core
import Foundation
import Testing

struct RoutineValueTests {
    @Test func routineDoneTakesAMorningOrEveningValueOrNone() {
        #expect(LogType.routineDone.accepts(.routine(.morning)))
        #expect(LogType.routineDone.accepts(.routine(.evening)))
        #expect(LogType.routineDone.accepts(nil))
        #expect(!LogType.routineDone.accepts(.night(.good)))
        #expect(!LogType.nightRating.accepts(.routine(.morning)))
    }

    @Test func storedValueReadsBack() {
        #expect(LogValue(type: .routineDone, raw: "evening") == .routine(.evening))
        #expect(LogValue(type: .routineDone, raw: "rough") == nil)
        #expect(LogValue.routine(.morning).rawValue == "morning")
    }

    @Test func routineValueIsSavedWithTheLog() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 19, 5))
        try await harness.logs.log(.routineDone, value: .routine(.evening), child: harness.child.id, source: .notification)

        let today = CareDay.containing(TestTime.date(26, 19, 5), calendar: TestTime.calendar)
        let events = try await harness.logs.events(for: today, child: harness.child.id)
        #expect(events.first?.value == .routine(.evening))
        #expect(events.first?.source == .notification)
    }
}

import Core
import Foundation
import Testing

/// "Worse since when?": changes, the day things turned rougher, and what changed before.
struct CareChangesTests {
    private let calendar = TestTime.calendar
    private let child = UUID()

    private func days(_ nights: [NightRating?], endingOn last: Int) -> [WeekDay] {
        let end = CareDay(year: 2026, month: 9, day: last)
        return nights.enumerated().map { index, rating in
            let day = end.adding(days: index - (nights.count - 1), calendar: calendar)
            let events = rating.map { [LogEntry(childID: child, type: .nightRating, value: .night($0), timestamp: day.noon(calendar: calendar))] } ?? []
            return WeekDay(summary: DaySummary(day: day, events: events, calendar: calendar))
        }
    }

    @Test func noticesWhenNightsTurnRougher() {
        let calm: [NightRating?] = [.good, .good, .okay, .good, nil, .good, .good]
        let week = days(calm + [.rough, .rough, .okay], endingOn: 26)
        #expect(CareChanges.rougherSince(week) == CareDay(year: 2026, month: 9, day: 24))
        #expect(CareChanges.rougherSince(days(calm + [.good, .okay, .good], endingOn: 26)) == nil)
        #expect(CareChanges.rougherSince(days([.rough, .rough], endingOn: 26)) == nil) // not enough to say
    }

    @Test func listsChangesAndWhatCameBefore() {
        let herb = PlanItemInfo(id: UUID(), planID: UUID(), kind: .supplement, text: "Antimicrobial herb", dose: "2 drops",
                                frequency: "twice daily", timing: nil, duration: nil, sourcePage: 2, sourceLine: nil, isConfirmed: true, order: 0)
        let plan = CarePlanInfo(id: UUID(), childID: child, provider: "Dr. Rivera", planDate: nil, sourceFileName: nil,
                                status: .active, startedAt: TestTime.date(10, 9), endedAt: nil)
        let logs = [
            LogEntry(childID: child, type: .supplement, value: .supplement(.started), timestamp: TestTime.date(20, 8), routineStepID: herb.id),
            LogEntry(childID: child, type: .patchTest, note: "Calendula balm · Inner forearm", timestamp: TestTime.date(22, 19)),
            LogEntry(childID: child, type: .itchEpisode, timestamp: TestTime.date(23, 2)),
        ]
        let changes = CareChanges.list(plans: [plan], items: [herb.id: herb], logs: logs)
        #expect(changes.map(\.text) == ["Patch test: Calendula balm", "Started Antimicrobial herb", "Started Dr. Rivera’s plan"])

        let before = CareChanges.before(CareDay(year: 2026, month: 9, day: 24), in: changes, calendar: calendar)
        #expect(before.map(\.text) == ["Patch test: Calendula balm", "Started Antimicrobial herb"])
    }
}

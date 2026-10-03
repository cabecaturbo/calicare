import Core
import Foundation
import Testing

/// Plan's Provider section: visits, follow-up timing, and messages left, from the plan's words.
struct ProviderTrackerTests {
    private let child = UUID()

    private func item(_ text: String) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: UUID(), kind: .followUp, text: text, dose: nil, frequency: nil, timing: nil,
                     duration: nil, sourcePage: 2, sourceLine: text, isConfirmed: true, order: 0)
    }

    @Test func readsThePlansWords() {
        #expect(ProviderTracker.followUpWeeks("follow-up visit in 4–6 weeks.")! == (4, 6))
        #expect(ProviderTracker.followUpWeeks("follow-up appointment in 6 weeks")! == (6, 6))
        #expect(ProviderTracker.followUpWeeks("vitamin d for 6 weeks") == nil)
        #expect(ProviderTracker.messageAllowance("up to 5 follow-up messages within 8 weeks.")! == (5, 8))
        #expect(ProviderTracker.messageAllowance("call the office") == nil)
    }

    @Test func visitsFollowUpAndMessagesLeft() {
        let plan = CarePlanInfo(id: UUID(), childID: child, provider: "Dr. Rivera", planDate: nil, sourceFileName: nil,
                                status: .active, startedAt: TestTime.date(1, 9), endedAt: nil)
        let visits = [
            VisitInfo(id: UUID(), childID: child, date: TestTime.date(2026, 8, 20, 10), provider: "Dr. Rivera", notes: nil),
            VisitInfo(id: UUID(), childID: child, date: TestTime.date(2026, 10, 14, 10), provider: "Dr. Rivera", notes: nil),
        ]
        let logs = [
            LogEntry(childID: child, type: .providerMessage, timestamp: TestTime.date(2026, 8, 30, 9)), // before the plan
            LogEntry(childID: child, type: .providerMessage, timestamp: TestTime.date(10, 9)),
            LogEntry(childID: child, type: .providerMessage, timestamp: TestTime.date(20, 9)),
        ]
        let tracker = ProviderTracker(
            plan: plan,
            items: [item("Follow-up visit in 4–6 weeks."), item("Up to 5 follow-up messages within 8 weeks.")],
            visits: visits, logs: logs, now: TestTime.date(26, 9), calendar: TestTime.calendar
        )
        #expect(tracker.nextVisit?.date == TestTime.date(2026, 10, 14, 10))
        #expect(tracker.lastVisit?.date == TestTime.date(2026, 8, 20, 10))
        #expect(tracker.followUp?.from == TestTime.date(29, 9))
        #expect(tracker.followUp?.to == TestTime.date(2026, 10, 13, 9))
        #expect(tracker.messages == ProviderTracker.Allowance(total: 5, used: 2, until: TestTime.date(2026, 10, 27, 9)))
        #expect(tracker.messages?.left == 3)
    }
}

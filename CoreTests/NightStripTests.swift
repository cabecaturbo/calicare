import Core
import Foundation
import Testing

/// The Night strip widget: which night a wake-up belongs to, where its dot
/// goes, and what VoiceOver reads.
struct NightStripTests {
    private let calendar = TestTime.calendar

    private func itch(_ date: Date) -> LogEntry {
        LogEntry(childID: UUID(), type: .itchEpisode, timestamp: date)
    }

    @Test func rowsRunOldestFirstAndEndWithLastNightByDay() {
        let now = TestTime.date(26, 9)
        let strip = NightStrip(events: [], count: 7, now: now, calendar: calendar)
        #expect(strip.nights.count == 7)
        #expect(strip.nights.last?.day == CareDay(year: 2026, month: 9, day: 26))
        #expect(strip.nights.first?.day == CareDay(year: 2026, month: 9, day: 20))
        #expect(strip.nights.last?.isTonight == false)
        #expect(strip.isEmpty)
    }

    @Test func fromSevenPMTheLastRowIsTonight() {
        let strip = NightStrip(events: [itch(TestTime.date(26, 21))], count: 5, now: TestTime.date(26, 22), calendar: calendar)
        #expect(strip.nights.last?.day == CareDay(year: 2026, month: 9, day: 27))
        #expect(strip.nights.last?.isTonight == true)
        #expect(strip.nights.last?.count == 1)
    }

    @Test func sevenPMStartsTheNextNight() {
        let events = [itch(TestTime.date(25, 18, 59)), itch(TestTime.date(25, 19, 0))]
        let strip = NightStrip(events: events, count: 3, now: TestTime.date(26, 9), calendar: calendar)
        // 6:59 PM is daytime on the 25th, not a wake-up; 7:00 PM is the first moment of the night ending the 26th.
        #expect(strip.nights.map(\.count) == [0, 0, 1])
        #expect(strip.nights.last?.positions == [0])
    }

    @Test func sevenAMEndsTheNight() {
        let events = [itch(TestTime.date(26, 6, 59)), itch(TestTime.date(26, 7, 0))]
        let strip = NightStrip(events: events, count: 1, now: TestTime.date(26, 9), calendar: calendar)
        #expect(strip.nights[0].count == 1)
        #expect(strip.nights[0].positions[0] > 0.99 && strip.nights[0].positions[0] < 1)
    }

    @Test func dotsSitWhereTheNightWas() {
        let events = [itch(TestTime.date(25, 19)), itch(TestTime.date(26, 1)), itch(TestTime.date(26, 4))]
        let strip = NightStrip(events: events, count: 1, now: TestTime.date(26, 9), calendar: calendar)
        #expect(strip.nights[0].positions == [0, 0.5, 0.75])
        #expect(strip.nights[0].wakeUps.count == 3)
    }

    @Test func onlyItchesBecomeDots() {
        let events = [
            itch(TestTime.date(26, 2)),
            LogEntry(childID: UUID(), type: .flare, timestamp: TestTime.date(26, 3)),
            LogEntry(childID: UUID(), type: .skinToday, value: .skin(.flaring), timestamp: TestTime.date(26, 12)),
        ]
        let strip = NightStrip(events: events, count: 1, now: TestTime.date(26, 13), calendar: calendar)
        #expect(strip.nights[0].count == 1)
        #expect(strip.nights[0].skin == .flaring)
    }

    @Test func aTimeZoneChangeMovesTheNight() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // 4:30 PM in Los Angeles is 7:30 PM in New York.
        let log = itch(TestTime.date(25, 16, 30))
        let la = NightStrip(events: [log], count: 1, now: TestTime.date(26, 9), calendar: calendar)
        let ny = NightStrip(events: [log], count: 1, now: TestTime.date(26, 9), calendar: newYork)
        #expect(la.nights[0].count == 0)
        #expect(ny.nights[0].count == 1)
    }

    @Test func springForwardNightIsShorterButStillEdgeToEdge() {
        // US clocks jump from 2 AM to 3 AM on March 8, 2026: the night is 11 hours.
        let night = CareDay(year: 2026, month: 3, day: 8).nightInterval(calendar: calendar)
        #expect(night.duration == 11 * 3600)
        let threeAM = TestTime.date(2026, 3, 8, 3)
        let strip = NightStrip(events: [itch(threeAM)], count: 1, now: TestTime.date(2026, 3, 8, 9), calendar: calendar)
        #expect(strip.nights[0].count == 1)
        #expect(abs(strip.nights[0].positions[0] - 7.0 / 11.0) < 0.0001)
    }

    @Test func fallBackNightIsLongerButStillEdgeToEdge() {
        // US clocks repeat 1 AM on November 1, 2026: the night is 13 hours.
        let night = CareDay(year: 2026, month: 11, day: 1).nightInterval(calendar: calendar)
        #expect(night.duration == 13 * 3600)
        let late = TestTime.date(2026, 11, 1, 6, 30)
        let strip = NightStrip(events: [itch(late)], count: 1, now: TestTime.date(2026, 11, 1, 9), calendar: calendar)
        #expect(abs(strip.nights[0].positions[0] - 12.5 / 13.0) < 0.0001)
    }

    @Test func voiceOverReadsEachNightPlainly() {
        let events = [itch(TestTime.date(25, 23)), itch(TestTime.date(26, 2)), itch(TestTime.date(26, 4))]
        let strip = NightStrip(events: events, count: 2, now: TestTime.date(26, 9), calendar: calendar)
        // Sept 25, 2026 is a Friday; the 26th a Saturday.
        #expect(strip.accessibilitySummary(calendar: calendar)
            == "Last 2 nights. Friday, no wake-ups logged. Saturday, 3 wake-ups.")
        #expect(NightStrip.shortWeekday(CareDay(year: 2026, month: 9, day: 26), calendar: calendar) == "Sat")
    }

    @Test func emptyStripInvitesTheFirstLog() {
        let strip = NightStrip(events: [], count: 7, now: TestTime.date(26, 9), calendar: calendar)
        #expect(strip.accessibilitySummary(calendar: calendar) == "Tap Log tonight, and your nights will show up here.")
    }

    @Test func progressLinkRoundTrips() {
        #expect(DeepLink.isProgress(DeepLink.progress))
        #expect(!DeepLink.isProgress(DeepLink.note))
    }

    @Test func dataSourceReadsTheChildsNights() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .widget, at: TestTime.date(26, 2))
        try await harness.logs.log(.itchEpisode, child: harness.child.id, source: .widget, at: TestTime.date(24, 23))
        let source = WidgetDataSource(container: harness.container, setting: .isolated(), feedbackStore: .isolated(), calendar: calendar)
        let strip = try await source.nightStrip(for: harness.child, at: TestTime.date(26, 10), count: 3)
        #expect(strip.nights.map(\.count) == [0, 1, 1])
    }
}

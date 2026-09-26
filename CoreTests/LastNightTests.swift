import Core
import Foundation
import Testing

struct LastNightTests {
    private let calendar = TestTime.calendar
    private let sept26 = CareDay(year: 2026, month: 9, day: 26)
    private let sept27 = CareDay(year: 2026, month: 9, day: 27)

    private func itch(_ date: Date) -> LogEntry {
        LogEntry(childID: nil, type: .itchEpisode, timestamp: date)
    }

    private func night(_ rating: NightRating, _ date: Date) -> LogEntry {
        LogEntry(childID: nil, type: .nightRating, value: .night(rating), timestamp: date)
    }

    private func report(at date: Date, _ events: [LogEntry]) -> LastNightReport {
        let today = CareDay.containing(date, calendar: calendar)
        return LastNightReport.resolve(
            at: date,
            today: DaySummary(day: today, events: events, calendar: calendar),
            previous: DaySummary(day: today.adding(days: -1, calendar: calendar), events: events, calendar: calendar),
            calendar: calendar
        )
    }

    @Test func sentences() {
        func sentence(_ rating: NightRating?, _ itches: Int, tonight: Bool = false) -> String {
            LastNightReport(day: sept26, rating: rating, itchyWakeUps: itches, isTonight: tonight).sentence
        }
        #expect(sentence(nil, 0) == "Nothing logged for last night.")
        #expect(sentence(.rough, 3) == "A rough night, 3 itchy wake-ups.")
        #expect(sentence(.good, 0) == "A good night.")
        #expect(sentence(.okay, 1) == "An okay night, 1 itchy wake-up.")
        #expect(sentence(nil, 2) == "2 itchy wake-ups last night.")
        #expect(sentence(nil, 1, tonight: true) == "1 itchy wake-up so far.")
    }

    @Test func daytimeMeansTheNightThatEndedThisMorning() {
        let events = [
            night(.rough, TestTime.date(26, 7, 5)),
            itch(TestTime.date(26, 1)),
            itch(TestTime.date(26, 3)),
            itch(TestTime.date(26, 4)),
            // Daytime itches aren't wake-ups.
            itch(TestTime.date(26, 10)),
        ]
        let result = report(at: TestTime.date(26, 12), events)
        #expect(result.day == sept26)
        #expect(!result.isTonight)
        #expect(result.heading == "Last night")
        #expect(result.sentence == "A rough night, 3 itchy wake-ups.")
    }

    @Test func eveningShowsLastNightUntilTonightHasLogs() {
        var events = [night(.good, TestTime.date(26, 7))]
        let early = report(at: TestTime.date(26, 21), events)
        #expect(early.day == sept26)
        #expect(early.sentence == "A good night.")

        events.append(itch(TestTime.date(26, 22)))
        let later = report(at: TestTime.date(26, 23), events)
        #expect(later.day == sept27)
        #expect(later.isTonight)
        #expect(later.heading == "Tonight so far")
        #expect(later.sentence == "1 itchy wake-up so far.")
    }

    @Test func nothingLogged() {
        let result = report(at: TestTime.date(26, 9), [])
        #expect(!result.hasLogs)
        #expect(result.sentence == "Nothing logged for last night.")
    }
}

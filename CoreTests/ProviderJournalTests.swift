import Core
import Foundation
import Testing

/// The daily journal in the provider's format.
struct ProviderJournalTests {
    private let child = UUID()

    @Test func oneLinePerLoggedDayInTheProvidersFormat() {
        let range = DoctorReport.Range(first: CareDay(year: 2026, month: 9, day: 25), last: CareDay(year: 2026, month: 9, day: 27))
        let events = [
            LogEntry(childID: child, type: .skinToday, value: .skin(.littleItchy), timestamp: TestTime.date(26, 18)),
            LogEntry(childID: child, type: .itchEpisode, timestamp: TestTime.date(26, 2)),
            LogEntry(childID: child, type: .flare, timestamp: TestTime.date(26, 14), bodyAreas: [.hands]),
            LogEntry(childID: child, type: .bowelMovement, value: .bowel(.good), timestamp: TestTime.date(26, 9)),
            LogEntry(childID: child, type: .nightRating, value: .night(.okay), timestamp: TestTime.date(26, 7)),
            LogEntry(childID: child, type: .mood, value: .mood(.cranky), timestamp: TestTime.date(26, 15)),
            LogEntry(childID: child, type: .note, note: "Swim class", timestamp: TestTime.date(26, 16)),
        ]
        let changes = [CareChange(date: TestTime.date(26, 8), text: "Started Vitamin D3")]
        let journal = ProviderJournal(childName: "Cal", range: range, events: events, changes: changes, calendar: TestTime.calendar)

        #expect(journal.days.count == 1) // the 25th and 27th have nothing
        let day = journal.days[0]
        #expect(day.changes == ["Started Vitamin D3"])
        #expect(day.skinAndItch == "Skin a little itchy · 1 itchy spell · Flare (hands)")
        #expect(day.bowel == "1 · good")
        #expect(day.sleep == "Okay night · 1 itchy wake-up")
        #expect(day.mood == "cranky")
        #expect(day.notes == ["Swim class"])

        let lines = journal.csv(calendar: TestTime.calendar).components(separatedBy: "\r\n")
        #expect(lines[0] == "Date,Changes,Rash and itch,Bowel movements,Sleep,Mood,Notes")
        #expect(lines[1].hasPrefix("2026-09-26,Started Vitamin D3,"))
        #expect(lines[2].contains("Not medical advice"))
    }

    @MainActor @Test func makesAPDF() {
        let range = DoctorReport.Range(first: CareDay(year: 2026, month: 9, day: 25), last: CareDay(year: 2026, month: 9, day: 27))
        let journal = ProviderJournal(childName: "Cal", range: range, events: [], changes: [], calendar: TestTime.calendar)
        #expect(ProviderJournalPDF.data(for: journal).starts(with: Data("%PDF".utf8)))
    }
}

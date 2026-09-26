import Core
import Foundation
import Testing

struct LogPhrasesTests {
    private let phrases = LogPhrases(calendar: TestTime.calendar, locale: Locale(identifier: "en_US"))

    private func entry(_ type: LogType, _ value: LogValue? = nil, at date: Date = TestTime.date(26, 9)) -> LogEntry {
        LogEntry(childID: nil, type: type, value: value, timestamp: date)
    }

    @Test func itchAtNightIsAWakeUp() {
        let text = phrases.logged(entry(.itchEpisode, at: TestTime.date(26, 2, 14)), childName: "Cal")
        #expect(text == "Logged itchy wake-up for Cal, 2:14 AM.")
    }

    @Test func itchInTheDaytimeIsASpell() {
        let text = phrases.logged(entry(.itchEpisode, at: TestTime.date(26, 15)), childName: "Cal")
        #expect(text == "Logged itchy spell for Cal, 3:00 PM.")
    }

    static let itchTimes: [(Int, Int, String)] = [
        (6, 59, "itchy wake-up"),
        (7, 0, "itchy spell"),
        (18, 59, "itchy spell"),
        (19, 0, "itchy wake-up"),
    ]

    static let valued: [(LogType, LogValue, String)] = [
        (.nightRating, .night(.rough), "rough night"),
        (.nightRating, .night(.good), "good night"),
        (.bowelMovement, .bowel(.hard), "hard bowel movement"),
        (.bowelMovement, .bowel(BowelMovement.none), "no bowel movement"),
        (.mood, .mood(.cranky), "cranky mood"),
    ]

    static let unvalued: [(LogType, String)] = [
        (.flare, "flare"),
        (.routineDone, "routine"),
        (.note, "note"),
    ]

    @Test(arguments: itchTimes)
    func itchWordingFollowsTheNightWindow(hour: Int, minute: Int, expected: String) {
        #expect(phrases.name(for: entry(.itchEpisode, at: TestTime.date(26, hour, minute))) == expected)
    }

    @Test(arguments: valued)
    func namesIncludeTheValue(type: LogType, value: LogValue, expected: String) {
        #expect(phrases.name(for: entry(type, value)) == expected)
    }

    @Test(arguments: unvalued)
    func namesWithoutAValue(type: LogType, expected: String) {
        #expect(phrases.name(for: entry(type)) == expected)
    }

    @Test func roughNightConfirmation() {
        let text = phrases.logged(entry(.nightRating, .night(.rough), at: TestTime.date(26, 7, 30)), childName: "Cal")
        #expect(text == "Logged rough night for Cal, 7:30 AM.")
    }

    @Test func minutesArePadded() {
        #expect(phrases.time(TestTime.date(26, 9, 5)) == "9:05 AM")
    }

    @Test func removedSaysWhatAndWhen() {
        #expect(phrases.removed(entry(.itchEpisode, at: TestTime.date(26, 2, 14))) == "Removed itchy wake-up, 2:14 AM.")
    }

    @Test func nothingToUndoIsKind() {
        #expect(LogPhrases.nothingToUndo == "Nothing to undo from the last 10 minutes. All good.")
    }
}

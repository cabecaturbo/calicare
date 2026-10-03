import Core
import Foundation
import Testing

/// "Your data" CSV export.
struct LogExportTests {
    private let cal = ChildInfo(id: UUID(), name: "Cal", birthDate: nil, colorTag: "sage", isActive: true)

    @Test func oneRowPerLogOldestFirstInPlainWords() {
        let entries = [
            LogEntry(childID: cal.id, type: .flare, timestamp: TestTime.date(26, 14, 5), loggedBy: "Dad", source: .widget, bodyAreas: [.hands, .elbowCreases]),
            LogEntry(childID: cal.id, type: .skinToday, value: .skin(.littleItchy), timestamp: TestTime.date(26, 9), source: .app),
        ]
        let lines = LogExport.csv(entries, children: [cal], calendar: TestTime.calendar).components(separatedBy: "\r\n")
        #expect(lines[0] == "Child,Date,Time,What,Value,Where,Note,Logged from,Logged by")
        #expect(lines[1] == "Cal,2026-09-26,09:00,Skin today,a little itchy,,,App,")
        #expect(lines[2] == "Cal,2026-09-26,14:05,Flare,,hands; elbow creases,,Widget,Dad")
        #expect(lines.count == 4) // header, two rows, trailing line break
    }

    @Test func notesAreQuotedAndFormulasDefused() {
        let entries = [
            LogEntry(childID: cal.id, type: .note, note: "Oat bath, then \"the\" cream\nslept", timestamp: TestTime.date(26, 20)),
            LogEntry(childID: UUID(), type: .note, note: "=SUM(A1)", timestamp: TestTime.date(26, 21)),
        ]
        let csv = LogExport.csv(entries, children: [cal], calendar: TestTime.calendar)
        #expect(csv.contains("\"Oat bath, then \"\"the\"\" cream\nslept\""))
        #expect(csv.contains("Removed child,2026-09-26,21:00,Note,,,'=SUM(A1),App,"))
    }
}

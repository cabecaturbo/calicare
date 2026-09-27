import Core
import Foundation
import PDFKit
import Testing

@MainActor
struct DoctorReportTests {
    let calendar = TestTime.calendar
    let cal = ChildInfo(id: UUID(), name: "Cal", birthDate: nil, colorTag: "sage", isActive: true)
    let sam = ChildInfo(id: UUID(), name: "Sam", birthDate: nil, colorTag: "clay", isActive: true)
    let locale = Locale(identifier: "en_US")

    func day(_ date: Int, month: Int = 9) -> CareDay {
        CareDay.containing(TestTime.date(2026, month, date, 12), calendar: calendar)
    }

    func entry(_ type: LogType, _ value: LogValue? = nil, day: Int, hour: Int, minute: Int = 0,
               note: String? = nil, child: ChildInfo? = nil, by: String = "Mom", source: EntrySource = .app) -> LogEntry {
        LogEntry(childID: (child ?? cal).id, type: type, value: value, note: note,
                 timestamp: TestTime.date(day, hour, minute), loggedBy: by, source: source)
    }

    func report(_ events: [LogEntry], from first: Int = 20, to last: Int = 26) -> DoctorReport {
        DoctorReport(child: cal, range: .init(first: day(first), last: day(last)), events: events, calendar: calendar, locale: locale)
    }

    // MARK: - Date range

    @Test func withoutAVisitTheRangeIsFourWeeks() {
        let range = DoctorReport.Range.standard(lastVisit: nil, now: TestTime.date(27, 10), calendar: calendar)
        #expect(range.last == day(27))
        #expect(range.first == day(31, month: 8))
        #expect(range.days(calendar: calendar).count == 28)
    }

    @Test func aKnownVisitStartsTheRange() {
        let range = DoctorReport.Range.standard(lastVisit: TestTime.date(15, 11), now: TestTime.date(27, 10), calendar: calendar)
        #expect(range.first == day(15))
        #expect(range.days(calendar: calendar).count == 13)
    }

    @Test func aFutureVisitIsIgnored() {
        let range = DoctorReport.Range.standard(lastVisit: TestTime.date(30, 9), now: TestTime.date(27, 10), calendar: calendar)
        #expect(range.days(calendar: calendar).count == 28)
    }

    @Test func rangesPutTheEarlierDayFirst() {
        let range = DoctorReport.Range(first: day(26), last: day(20))
        #expect(range.first == day(20))
        #expect(range.last == day(26))
    }

    // MARK: - Content

    @Test func theTableListsEveryLogInOrderForThisChildOnly() {
        let events = [
            entry(.nightRating, .night(.rough), day: 21, hour: 7, minute: 5, by: "Dad", source: .notification),
            entry(.itchEpisode, day: 21, hour: 2, source: .widget),
            entry(.note, day: 22, hour: 18, note: "New lotion started today"),
            entry(.itchEpisode, day: 22, hour: 3, child: sam),
            entry(.flare, day: 19, hour: 12),                   // before the range
            entry(.bowelMovement, .bowel(.hard), day: 26, hour: 20), // 8 PM on the 26th: next care day
        ]
        let report = report(events)

        #expect(report.rows.map(\.what) == ["Itchy wake-up", "Rough night", "Note"])
        #expect(report.rows[0].date == "Sep 21")
        #expect(report.rows[0].time == "2:00 AM")
        #expect(report.rows[0].source == "Widget")
        #expect(report.rows[1].loggedBy == "Dad")
        #expect(report.rows[1].source == "Notification")
        #expect(report.rows[2].note == "New lotion started today")
        #expect(report.notes.map(\.note) == ["New lotion started today"])
    }

    @Test func summaryCountsAreJustCounts() {
        let events = [
            entry(.nightRating, .night(.good), day: 21, hour: 8),
            entry(.nightRating, .night(.rough), day: 22, hour: 8),
            entry(.itchEpisode, day: 22, hour: 2),
            entry(.itchEpisode, day: 22, hour: 3),
            entry(.itchEpisode, day: 22, hour: 14),
            entry(.flare, day: 23, hour: 12),
            entry(.routineDone, .routine(.evening), day: 23, hour: 18),
            entry(.bowelMovement, .bowel(.loose), day: 24, hour: 9),
            entry(.mood, .mood(.cranky), day: 24, hour: 10),
        ]
        let report = report(events)
        #expect(report.daysWithLogs == 4)
        #expect(report.days.count == 7)
        #expect((report.goodNights, report.okayNights, report.roughNights) == (1, 0, 1))
        #expect(report.itchyWakeUps == 2)
        #expect(report.daytimeItches == 1)
        #expect(report.flares == 1)
        #expect(report.routineDays == 1)
        #expect(report.bowelMovements == 1)
        #expect(report.moods == ["Cranky": 1])
        #expect(report.days.first { $0.day == day(24) }?.bowelMovements == ["loose"])
        #expect(report.days.first { $0.day == day(20) }?.night == nil, "unlogged days stay empty")
    }

    @Test func theFooterNamesTheChildTheDatesAndTheDisclaimer() {
        let report = report([])
        #expect(report.dateRange == "Sep 20 – Sep 26, 2026")
        #expect(report.footer == "Cal · Sep 20 – Sep 26, 2026 · Not medical advice. Logged by parent.")
    }

    // MARK: - PDF

    @Test func thePDFHasAFooterOnEveryPage() throws {
        // Four weeks with several logs a day: the full log spans pages.
        let events = (1...26).flatMap { date -> [LogEntry] in
            [entry(.nightRating, .night(date.isMultiple(of: 3) ? .rough : .good), day: date, hour: 8),
             entry(.itchEpisode, day: date, hour: 2),
             entry(.routineDone, .routine(.morning), day: date, hour: 9),
             entry(.note, day: date, hour: 12, note: "Note for the \(date)th")]
        }
        let report = report(events, from: 1, to: 26)
        let pdf = try #require(PDFDocument(data: DoctorReportPDF.data(for: report)))

        #expect(pdf.pageCount >= 5, "summary, day by day, notes, and a multi-page log")
        for index in 0..<pdf.pageCount {
            let text = pdf.page(at: index)?.string ?? ""
            #expect(text.contains("Not medical advice. Logged by parent."), "page \(index + 1)")
            #expect(text.contains("Page \(index + 1) of \(pdf.pageCount)"))
        }
        #expect(pdf.page(at: 0)?.string?.contains("Care log for Cal") == true)
        if let folder = ProcessInfo.processInfo.environment["DESIGN_OUT"] {
            try? DoctorReportPDF.data(for: report).write(to: URL(fileURLWithPath: folder).appendingPathComponent("doctor-report.pdf"))
        }
    }
}

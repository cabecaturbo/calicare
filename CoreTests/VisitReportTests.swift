import Core
import Foundation
import PDFKit
import Testing
import UIKit

/// The one-page doctor report. Weeks start Sun Sep 13, 2026 (Los Angeles).
/// Set DESIGN_OUT (TEST_RUNNER_DESIGN_OUT) to also save the PDFs and page PNGs.
@MainActor
struct VisitReportTests {
    let calendar = TestTime.calendar
    let locale = Locale(identifier: "en_US")
    let cal = ChildInfo(id: UUID(), name: "Cal", birthDate: TestTime.date(2023, 3, 2, 12), colorTag: "sage", isActive: true)
    let now = TestTime.date(2026, 10, 10, 12)

    func day(_ month: Int, _ day: Int) -> CareDay { CareDay(year: 2026, month: month, day: day) }

    func skin(_ answer: SkinToday, _ month: Int, _ dayOfMonth: Int) -> LogEntry {
        LogEntry(childID: cal.id, type: .skinToday, value: .skin(answer), timestamp: TestTime.date(2026, month, dayOfMonth, 18))
    }

    func night(_ rating: NightRating, _ month: Int, _ dayOfMonth: Int) -> LogEntry {
        LogEntry(childID: cal.id, type: .nightRating, value: .night(rating), timestamp: TestTime.date(2026, month, dayOfMonth, 8))
    }

    func plan(started: Date?, provider: String = "Dr. Rivera") -> CarePlanInfo {
        CarePlanInfo(id: UUID(), childID: cal.id, provider: provider, planDate: nil, sourceFileName: nil,
                     status: .active, startedAt: started, endedAt: nil)
    }

    /// Four weeks Sep 13 – Oct 10: rough before the plan (Sep 27), calmer after.
    var fourWeeks: [LogEntry] {
        (0..<28).flatMap { offset -> [LogEntry] in
            let date = day(9, 13).adding(days: offset, calendar: calendar)
            let before = offset < 14
            let answer: SkinToday = before ? (offset % 7 < 4 ? .flaring : .littleItchy) : (offset % 7 == 0 ? .flaring : .calm)
            return [skin(answer, date.month, date.day), night(before ? .okay : .good, date.month, date.day)]
        }
    }

    func report(_ events: [LogEntry], first: CareDay, last: CareDay, plan: CarePlanInfo? = nil,
                visits: [VisitInfo] = []) -> VisitReport {
        VisitReport(child: cal, range: DoctorReport.Range(first: first, last: last), events: events, plan: plan,
                    visits: visits, parentName: "Matt", now: now, calendar: calendar, locale: locale)
    }

    @Test func titleSubtitleAndHeader() {
        let visit = VisitInfo(id: UUID(), childID: cal.id, date: TestTime.date(2026, 10, 30, 10), provider: "Rivera", notes: nil,
                              questions: "Can we stop the oil at bedtime?")
        let report = report(fourWeeks, first: day(9, 13), last: day(10, 10), plan: plan(started: nil), visits: [visit])
        #expect(report.title == "Cal’s skin, Sep 13 – Oct 10")
        #expect(report.subtitle == "Age 3 · 4 weeks, logged by Matt")
        #expect(report.header == "For Dr. Rivera · visit Oct 30")
        #expect(report.questions == "Can we stop the oil at bedtime?")
        #expect(report.footer == "Logged by Cal’s parent in Cali Care. Not medical advice.")

        let noOne = self.report([], first: day(9, 13), last: day(10, 10))
        #expect(noOne.header == nil)
        #expect(noOne.questions == nil)
        #expect(noOne.summary == "Not much was logged in these weeks.")
    }

    @Test func summarySinceThePlanStarted() {
        let report = report(fourWeeks, first: day(9, 13), last: day(10, 10),
                            plan: plan(started: TestTime.date(2026, 9, 27, 9)))
        #expect(report.summary == "Calmer since the plan started Sep 27: flaring days went from 4 a week to 1.")
        #expect(report.weeks.count == 4)
        #expect(report.weeks.map(\.planStarts) == [false, false, true, false])
        #expect(report.weeks[3].goodNights == 7)
        #expect(report.weeks[0].goodNights == 0)
    }

    @Test func followingThePlanCountsSinceItStarted() {
        let start = plan(started: TestTime.date(2026, 9, 27, 9))
        let (steps, items, logs) = planPieces(start)
        let report = VisitReport(child: cal, range: DoctorReport.Range(first: day(9, 13), last: day(10, 10)),
                                 events: fourWeeks + logs, plan: start, items: items, steps: steps,
                                 parentName: "Matt", now: now, calendar: calendar, locale: locale)
        #expect(report.following.first == VisitReport.PlanLine(name: "Moisturizer", often: "Morning and bedtime", done: "26 of 28"))
        #expect(report.following.contains { $0.name == "Vitamin D3 drops" && $0.done == "1.0× a day" })
        #expect(report.notStarted == ["Probiotic powder"])
        #expect(report.notes.first?.text == "Red patch behind the knees after the park.")
    }

    /// Moisturizer morning and bedtime (done 13 of 14 days each), vitamin D
    /// given daily, probiotic not started, and a note.
    func planPieces(_ plan: CarePlanInfo) -> ([RoutineStepInfo], [PlanItemInfo], [LogEntry]) {
        let morning = RoutineStepInfo(id: UUID(), childID: cal.id, name: "Moisturizer", time: .morning, order: 0, isActive: true)
        let bedtime = RoutineStepInfo(id: UUID(), childID: cal.id, name: "Moisturizer", time: .evening, order: 1, isActive: true)
        let vitamin = PlanItemInfo(id: UUID(), planID: plan.id, kind: .supplement, text: "Vitamin D3 drops", dose: "1 drop",
                                   frequency: "once daily", timing: nil, duration: nil, sourcePage: nil, sourceLine: nil,
                                   isConfirmed: true, order: 0, isGiving: true)
        let probiotic = PlanItemInfo(id: UUID(), planID: plan.id, kind: .supplement, text: "Probiotic powder", dose: nil,
                                     frequency: "once daily", timing: nil, duration: nil, sourcePage: nil, sourceLine: nil,
                                     isConfirmed: true, order: 1, isGiving: false)
        var logs: [LogEntry] = []
        for offset in 0..<14 {
            let date = day(9, 27).adding(days: offset, calendar: calendar)
            if offset != 3 {
                logs.append(LogEntry(childID: cal.id, type: .routineDone, value: .routine(.morning),
                                     timestamp: TestTime.date(2026, date.month, date.day, 8), routineStepID: morning.id))
                logs.append(LogEntry(childID: cal.id, type: .routineDone, value: .routine(.evening),
                                     timestamp: TestTime.date(2026, date.month, date.day, 18), routineStepID: bedtime.id))
            }
            logs.append(LogEntry(childID: cal.id, type: .supplement, value: .supplement(.taken),
                                 timestamp: TestTime.date(2026, date.month, date.day, 9), routineStepID: vitamin.id))
        }
        logs.append(LogEntry(childID: cal.id, type: .note, note: "Red patch behind the knees after the park.",
                             timestamp: TestTime.date(2026, 10, 6, 17)))
        logs.append(LogEntry(childID: cal.id, type: .note, note: "Slept through for the first time in weeks.",
                             timestamp: TestTime.date(2026, 10, 2, 7)))
        return ([morning, bedtime], [vitamin, probiotic], logs)
    }

    @Test func pagesAndRenders() throws {
        let start = plan(started: TestTime.date(2026, 9, 27, 9))
        let (steps, items, logs) = planPieces(start)
        let visit = VisitInfo(id: UUID(), childID: cal.id, date: TestTime.date(2026, 10, 30, 10), provider: "Dr. Rivera", notes: nil,
                              questions: "Can we stop the oil at bedtime now that the knees are calm?\nIs it OK to try eggs again?")
        func make(_ first: CareDay) -> VisitReport {
            VisitReport(child: cal, range: DoctorReport.Range(first: first, last: day(10, 10)), events: fourWeeks + logs,
                        plan: start, items: items, steps: steps, visits: [visit], parentName: "Matt", now: now,
                        calendar: calendar, locale: locale)
        }
        let short = make(day(9, 13))
        let long = make(day(8, 16))
        #expect(long.weeks.count == 8)
        for (name, report, pages) in [("visit-report-4-weeks", short, 1), ("visit-report-8-weeks", long, 2)] {
            let data = VisitReportPDF.data(for: report)
            let document = try #require(PDFDocument(data: data))
            #expect(document.pageCount == pages)
            #expect(document.string?.contains("Not medical advice.") == true)
            save(document, data, name)
        }
    }

    private func save(_ document: PDFDocument, _ data: Data, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["DESIGN_OUT"] else { return }
        let url = URL(fileURLWithPath: folder)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try? data.write(to: url.appendingPathComponent("\(name).pdf"))
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let image = page.thumbnail(of: CGSize(width: 1224, height: 1584), for: .mediaBox)
            try? image.pngData()?.write(to: url.appendingPathComponent("\(name)-page\(index + 1).png"))
        }
    }
}

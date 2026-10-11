import Core
import Foundation
import Testing
import UIKit

/// The "Share this week" picture: what it shows, and that it renders.
/// Set DESIGN_OUT (TEST_RUNNER_DESIGN_OUT) to also save the PNGs for review.
@MainActor
struct WeekShareCardTests {
    let calendar = TestTime.calendar
    let locale = Locale(identifier: "en_US")
    let cal = ChildInfo(id: UUID(), name: "Cal", birthDate: nil, colorTag: "sage", isActive: true)
    /// Care days Sun Sep 20 – Sat Sep 26, 2026.
    var weekEnding: CareDay { CareDay.containing(TestTime.date(26, 12), calendar: calendar) }

    func entry(_ type: LogType, _ value: LogValue? = nil, day: Int, hour: Int, minute: Int = 0) -> LogEntry {
        LogEntry(childID: cal.id, type: type, value: value, timestamp: TestTime.date(day, hour, minute))
    }

    func skin(_ answer: SkinToday, _ day: Int, hour: Int = 18) -> LogEntry {
        entry(.skinToday, .skin(answer), day: day, hour: hour)
    }

    func card(_ events: [LogEntry]) -> WeekShareCard {
        let report = WeeklyReport(child: cal, weekEnding: weekEnding, events: events, calendar: calendar)
        return WeekShareCard(report: report, events: events, calendar: calendar, locale: locale)
    }

    @Test func aDayWithSeveralAnswersShowsTheRoughest() {
        let card = card([skin(.flaring, 21, hour: 9), skin(.calm, 21, hour: 17), skin(.littleItchy, 22)])
        #expect(card.days[1].skin == .flaring)
        #expect(card.days[2].skin == .littleItchy)
    }

    @Test func daysWithoutAnAnswerStayEmpty() {
        let card = card([skin(.calm, 20), skin(.calm, 26)])
        #expect(card.days.count == 7)
        #expect(card.days.map(\.skin) == [.calm, nil, nil, nil, nil, nil, .calm])
        #expect(card.days.map(\.label) == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
    }

    @Test func theWeekLabel() {
        #expect(WeekShareCard.rangeLabel(ending: weekEnding, calendar: calendar, locale: locale) == "Sep 20–26")
        let crossing = CareDay(year: 2026, month: 10, day: 5)
        #expect(WeekShareCard.rangeLabel(ending: crossing, calendar: calendar, locale: locale) == "Sep 29–Oct 5")
    }

    @Test func bottomLinesHideWithoutData() {
        let empty = card([])
        #expect(empty.nightsLine == nil)
        #expect(empty.worthWatching == nil)
        #expect(empty.headline == "Not enough logs yet for a summary")

        let calmLastWeek = (13...19).map { entry(.nightRating, .night(.good), day: $0, hour: 8) }
        let flaryWeek = (20...26).flatMap { day in
            [entry(.nightRating, .night(day < 24 ? .good : .okay), day: day, hour: 8),
             entry(.flare, day: day, hour: 11)]
        }
        let full = card(calmLastWeek + flaryWeek)
        #expect(full.nightsLine == "4 of 7 good nights.")
        #expect(full.worthWatching == "More flares.")
    }

    @Test func rendersAt3x() throws {
        let cases: [(String, WeekShareCard)] = [
            ("typical", .sample(skins: [.littleItchy, .flaring, .littleItchy, .calm, .calm, .calm, .calm], watch: nil)),
            ("all-calm", .sample(skins: Array(repeating: .calm, count: 7), nights: "7 of 7 good nights.", watch: nil)),
            ("rough", .sample(headline: "A harder week", skins: [.flaring, .veryRough, .veryRough, .flaring, .flaring, .littleItchy, .veryRough],
                              nights: "1 of 7 good nights.", watch: "Itchy wake-ups went up.")),
            ("two-unanswered", .sample(headline: "About the same as last week", skins: [.calm, nil, .littleItchy, nil, .calm, .littleItchy, .calm], watch: nil)),
            ("long-name", .sample(name: "Maximilian Alexander", headline: "Not enough logs yet for a summary",
                                  skins: [nil, nil, nil, nil, .calm, .littleItchy, .calm], nights: nil, watch: nil)),
            ("real-week", card((13...19).map { entry(.nightRating, .night(.okay), day: $0, hour: 8) }
                + (20...26).flatMap { [entry(.nightRating, .night($0 == 22 ? .rough : .good), day: $0, hour: 8), skin($0 < 23 ? .littleItchy : .calm, $0)] })),
        ]
        for (name, card) in cases {
            let image = try #require(WeeklyCardRenderer.shareImage(card))
            #expect(image.size == WeekShareCardView.size)
            #expect(image.scale == 3)
            save(image, "week-share-\(name)")
        }
    }

    @Test func theFileIsNamedForTheWeek() throws {
        let url = try WeeklyCardRenderer.shareFile(card([skin(.calm, 22)]))
        #expect(url.lastPathComponent == "Cal's week Sep 20–26.png")
    }

    private func save(_ image: UIImage, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["DESIGN_OUT"] else { return }
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? image.pngData()?.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
    }
}

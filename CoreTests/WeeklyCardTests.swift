import Core
import Foundation
import Testing
import UIKit

/// Renders the weekly card with sample data and the empty state.
/// Set DESIGN_OUT (TEST_RUNNER_DESIGN_OUT) to also save the PNGs for review.
@MainActor
struct WeeklyCardTests {
    let calendar = TestTime.calendar
    let cal = ChildInfo(id: UUID(), name: "Cal", birthDate: nil, colorTag: "sage", isActive: true)
    var weekEnding: CareDay { CareDay.containing(TestTime.date(26, 12), calendar: calendar) }

    func entry(_ type: LogType, _ value: LogValue? = nil, day: Int, hour: Int) -> LogEntry {
        LogEntry(childID: cal.id, type: type, value: value, timestamp: TestTime.date(day, hour))
    }

    var sampleWeek: [LogEntry] {
        let lastWeek = (13...19).flatMap { [entry(.nightRating, .night(.okay), day: $0, hour: 8)] }
        let thisWeek = (20...26).flatMap { day -> [LogEntry] in
            var logs = [entry(.nightRating, .night(day == 23 ? .rough : .good), day: day, hour: 8),
                        entry(.routineDone, .routine(.morning), day: day, hour: 9)]
            if day >= 23 { logs += [entry(.itchEpisode, day: day, hour: 2), entry(.itchEpisode, day: day, hour: 3)] }
            if day.isMultiple(of: 2) { logs.append(entry(.bowelMovement, day: day, hour: 10)) }
            logs.append(entry(.mood, .mood(.great), day: day, hour: 12))
            return logs
        }
        return lastWeek + thisWeek
    }

    @Test func rendersASampleWeekAt3x() throws {
        let report = WeeklyReport(child: cal, weekEnding: weekEnding, events: sampleWeek, calendar: calendar)
        #expect(report.worthWatching != nil, "the sample shows the ochre line")
        let image = try #require(WeeklyCardRenderer.image(for: report, calendar: calendar))
        #expect(image.size == WeeklyCardView.size)
        #expect(image.scale == 3)
        save(image, "weekly-card-sample")
    }

    @Test func rendersTheEmptyState() throws {
        let report = WeeklyReport(child: cal, weekEnding: weekEnding, events: [], calendar: calendar)
        #expect(report.headline == .notEnoughLogs)
        let image = try #require(WeeklyCardRenderer.image(for: report, calendar: calendar))
        #expect(image.size == WeeklyCardView.size)
        save(image, "weekly-card-empty")
    }

    @Test func writesANamedFileForSharing() throws {
        let report = WeeklyReport(child: cal, weekEnding: weekEnding, events: sampleWeek, calendar: calendar)
        let url = try WeeklyCardRenderer.file(for: report, calendar: calendar)
        #expect(url.lastPathComponent == "Cal week Sep 20 – 26.png")
        #expect(try Data(contentsOf: url).count > 10_000)
    }

    @Test func dateRangesCrossMonths() {
        let report = WeeklyReport(
            child: cal, weekEnding: CareDay.containing(TestTime.date(2026, 10, 3, 12), calendar: calendar),
            events: [], calendar: calendar
        )
        #expect(report.dateRange(calendar: calendar, locale: Locale(identifier: "en_US")) == "Sep 27 – Oct 3")
    }

    private func save(_ image: UIImage, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["DESIGN_OUT"] else { return }
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        try? image.pngData()?.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
    }
}

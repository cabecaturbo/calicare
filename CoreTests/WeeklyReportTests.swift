import Core
import Foundation
import Testing

/// Weeks end Saturday Sept 26, 2026 (care days Sept 20–26); last week is Sept 13–19.
/// Times are Los Angeles. A care day runs 7 PM the evening before to 7 PM.
struct WeeklyReportTests {
    let calendar = TestTime.calendar
    let cal = ChildInfo(id: UUID(), name: "Cal", birthDate: nil, colorTag: "sage", isActive: true)
    let sam = ChildInfo(id: UUID(), name: "Sam", birthDate: nil, colorTag: "clay", isActive: true)
    var weekEnding: CareDay { CareDay.containing(TestTime.date(26, 12), calendar: calendar) }

    // MARK: - Helpers

    func log(_ type: LogType, _ value: LogValue? = nil, day: Int, hour: Int, child: ChildInfo? = nil) -> LogEntry {
        LogEntry(childID: (child ?? cal).id, type: type, value: value, timestamp: TestTime.date(day, hour))
    }

    /// An itchy wake-up: 2 AM belongs to that morning's care day.
    func wakeUp(_ day: Int, child: ChildInfo? = nil) -> LogEntry { log(.itchEpisode, day: day, hour: 2, child: child) }
    func night(_ rating: NightRating, _ day: Int) -> LogEntry { log(.nightRating, .night(rating), day: day, hour: 8) }
    func routine(_ day: Int) -> LogEntry { log(.routineDone, .routine(.morning), day: day, hour: 9) }

    func report(_ events: [LogEntry], for child: ChildInfo? = nil) -> WeeklyReport {
        WeeklyReport(child: child ?? cal, weekEnding: weekEnding, events: events, calendar: calendar)
    }

    /// Last week: a rough night and a wake-up every day.
    var hardLastWeek: [LogEntry] {
        (13...19).flatMap { [night(.rough, $0), wakeUp($0)] }
    }

    // MARK: - Tests

    @Test func aNormalCalmerWeek() {
        let thisWeek = (20...26).flatMap { day -> [LogEntry] in
            [night(day < 25 ? .good : .okay, day), routine(day), log(.bowelMovement, day: day, hour: 10)]
        } + [wakeUp(21), log(.mood, .mood(.great), day: 22, hour: 12), log(.mood, .mood(.great), day: 23, hour: 12),
             log(.mood, .mood(.cranky), day: 24, hour: 12)]
        let report = report(thisWeek + hardLastWeek)

        #expect(report.daysWithLogs == 7)
        #expect(report.goodNights == 5)
        #expect(report.ratedNights == 7)
        #expect(report.itchyWakeUps == 1)
        #expect(report.itchyWakeUpsLastWeek == 7)
        #expect(report.routinesDone == 7)
        #expect(report.routineDays == 7)
        #expect(report.bowelMovements == 7)
        #expect(report.usualMood == .great)
        #expect(report.moodsLogged == 3)
        #expect(report.days.count == 7)
        #expect(report.headline == .calmer)
        #expect(report.headline.text == "A calmer week")
        #expect(report.worthWatching == nil)
        #expect(report.newSafeFoods.isEmpty)
    }

    @Test func aHarderWeekNoticesTheChangeWithoutExplainingIt() {
        let calmLastWeek = (13...19).map { night(.good, $0) }
        let thisWeek = (20...26).flatMap { [night(.rough, $0), wakeUp($0)] }
        let report = report(thisWeek + calmLastWeek)

        #expect(report.headline == .harder)
        #expect(report.worthWatching == "Itchy wake-ups went up this week.")
        #expect(report.itchyWakeUpsLastWeek == 0)
    }

    @Test func aboutTheSame() {
        let weeks = (13...26).map { night(.okay, $0) }
        let report = report(weeks)
        #expect(report.headline == .aboutTheSame)
        #expect(report.headline.text == "About the same as last week")
        #expect(report.worthWatching == nil)
    }

    @Test func anEmptyWeekHasNoSummaryAndNoFailures() {
        let report = report(hardLastWeek)
        #expect(report.daysWithLogs == 0)
        #expect(report.headline == .notEnoughLogs)
        #expect(report.headline.text == "Not enough logs yet for a summary")
        #expect(report.worthWatching == nil)
        #expect(report.days.allSatisfy { !$0.hasLogs }, "empty days are just empty")
        #expect(report.goodNights == 0)
    }

    @Test func aPartialWeekCountsOnlyLoggedDays() {
        let thisWeek = [night(.good, 20), night(.good, 22), night(.rough, 25), routine(25)]
        let report = report(thisWeek + hardLastWeek)

        #expect(report.daysWithLogs == 3)
        #expect(report.goodNights == 2)
        #expect(report.ratedNights == 3)
        #expect(report.routineDays == 1)
        #expect(report.headline == .calmer)
        #expect(report.days.filter(\.hasLogs).count == 3)
    }

    @Test func twoDaysIsNotEnoughToSummarize() {
        let report = report([night(.good, 21), night(.good, 22)] + hardLastWeek)
        #expect(report.headline == .notEnoughLogs)
    }

    @Test func aFirstWeekDoesntCompareWithNothing() {
        let report = report((20...26).map { night(.rough, $0) })
        #expect(report.headline == .firstWeek)
        #expect(report.itchyWakeUpsLastWeek == nil)
        #expect(report.worthWatching == nil)
    }

    @Test func twoChildrenStaySeparate() {
        let calsWeek = (20...26).map { night(.good, $0) }
        let samsWeek = (20...26).flatMap { [wakeUp($0, child: sam), wakeUp($0, child: sam)] }
        let forCal = report(calsWeek + samsWeek)
        let forSam = report(calsWeek + samsWeek, for: sam)

        #expect(forCal.itchyWakeUps == 0)
        #expect(forCal.goodNights == 7)
        #expect(forSam.itchyWakeUps == 14)
        #expect(forSam.goodNights == 0)
        #expect(forSam.child.name == "Sam")
    }

    @Test func nightBoundariesFollowTheCareDay() {
        let events = [
            log(.itchEpisode, day: 19, hour: 18),  // 6 PM Sat 19th: last week's Sept 19 care day
            log(.itchEpisode, day: 19, hour: 23),  // 11 PM: the night that ends Sept 20, this week
            log(.itchEpisode, day: 26, hour: 18),  // 6 PM on the 26th: still this week (daytime)
            log(.itchEpisode, day: 26, hour: 20),  // 8 PM on the 26th: next week's first night
        ]
        let report = report(events)
        #expect(report.itchyWakeUps == 1, "only the 11 PM itch is a wake-up in this week")
        #expect(report.days.first?.nightItches == 1)
        #expect(report.days.last?.hasLogs == true)
        #expect(report.daysWithLogs == 2)
    }

    @Test func timeZonesDecideWhichNightALogBelongsTo() {
        // 3 AM Sept 22 in Los Angeles is 7 PM Sept 22 in Tokyo: a night there, the next care day.
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let event = log(.itchEpisode, day: 22, hour: 3)
        let la = report([event])
        let inTokyo = WeeklyReport(
            child: cal, weekEnding: CareDay.containing(event.timestamp, calendar: tokyo),
            events: [event], calendar: tokyo
        )
        #expect(la.itchyWakeUps == 1)
        #expect(la.days.first { $0.hasLogs }?.day == CareDay.containing(TestTime.date(22, 12), calendar: calendar))
        #expect(inTokyo.itchyWakeUps == 1)
        #expect(inTokyo.days.last?.day != la.days.first { $0.hasLogs }?.day)
    }

    @Test func worthWatchingOnlyForClearChanges() {
        let lastWeek = (13...19).map { night(.okay, $0) } + [wakeUp(14)]
        let slightlyMore = (20...26).map { night(.okay, $0) } + [wakeUp(21), wakeUp(22)]
        #expect(report(lastWeek + slightlyMore).worthWatching == nil, "up by 1 isn't a clear change")

        let moreFlares = (20...26).map { night(.okay, $0) } + [log(.flare, day: 21, hour: 12), log(.flare, day: 23, hour: 12)]
        #expect(report(lastWeek + moreFlares).worthWatching == "More flares this week.")
    }

    @Test func theHeadlineNeverContradictsWorthWatching() {
        // Nights rated good, but wake-ups jumped: not "a calmer week".
        let lastWeek = (13...19).map { night(.okay, $0) }
        let thisWeek = (20...26).map { night(.good, $0) } + (23...26).flatMap { [wakeUp($0), wakeUp($0)] }
        let report = report(lastWeek + thisWeek)
        #expect(report.worthWatching == "Itchy wake-ups went up this week.")
        #expect(report.headline == .aboutTheSame)
    }

    @Test func worthWatchingNeverClaimsACause() {
        let calmLastWeek = (13...19).map { night(.good, $0) }
        let roughWeek = (20...26).flatMap { [night(.rough, $0), wakeUp($0), log(.flare, day: $0, hour: 12)] }
        let line = report(roughWeek + calmLastWeek).worthWatching ?? ""
        #expect(!line.lowercased().contains("cause"))
        #expect(!line.lowercased().contains("because"))
    }
}

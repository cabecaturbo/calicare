import Core
import Foundation
import Testing

/// The medium and Lock Screen widgets' "Last night / Tonight" line, Flare, and the note link.
struct WidgetNightTests {
    private func source(_ harness: TestHarness) -> WidgetDataSource {
        WidgetDataSource(container: harness.container, setting: .isolated(), feedbackStore: .isolated(), calendar: TestTime.calendar)
    }

    @Test func byDayItCountsLastNightsWakeUps() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let id = harness.child.id
        try await harness.logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(25, 23))
        try await harness.logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(26, 2))
        try await harness.logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(26, 12))

        let snapshot = try await source(harness).snapshot(for: harness.child, at: TestTime.date(26, 14))
        #expect(!snapshot.isNight)
        #expect(snapshot.nightWakeUps == 2)
    }

    @Test func fromSevenPMItCountsTonight() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        let id = harness.child.id
        try await harness.logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(26, 2))
        try await harness.logs.log(.itchEpisode, child: id, source: .widget, at: TestTime.date(26, 21))

        let snapshot = try await source(harness).snapshot(for: harness.child, at: TestTime.date(26, 22))
        #expect(snapshot.isNight)
        #expect(snapshot.nightWakeUps == 1)
    }

    @Test func flareLogsAFlare() {
        #expect(WidgetAction.flare.logType == .flare)
        #expect(WidgetAction.flare.value == nil)
    }

    @Test func noteLinkRoundTrips() {
        #expect(DeepLink.isNote(DeepLink.note))
        #expect(DeepLink.note.absoluteString == "calicare://note")
        #expect(!DeepLink.isNote(URL(string: "calicare://week")!))
    }
}

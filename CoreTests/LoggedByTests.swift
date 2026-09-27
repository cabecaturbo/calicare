import Core
import Foundation
import SwiftData
import Testing

struct LoggedByTests {
    @Test func signedOutLogsSayYou() {
        let settings = AccountSettings(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        #expect(LoggedBy.current(settings: settings) == "You")
        settings.displayName = "Dad"
        #expect(LoggedBy.current(settings: settings) == "Dad")
    }

    @Test func nobodyGetsABylineWhenAlone() {
        #expect(LoggedBy.byline("Dad", myName: "Mom", householdSize: 1) == nil)
    }

    @Test func sharedHouseholdsShowWhoLoggedIt() {
        #expect(LoggedBy.byline("Dad", myName: "Mom", householdSize: 2) == "by Dad")
        #expect(LoggedBy.byline("Mom", myName: "Mom", householdSize: 2) == "by you")
        #expect(LoggedBy.byline("You", myName: "Mom", householdSize: 3) == "by you")
        #expect(LoggedBy.byline("Me", myName: nil, householdSize: 2) == "by you", "pre-2.5 logs")
    }

    @Test func firstSyncPutsYourNameOnEarlierLogs() async throws {
        let container = try CaliCareModelContainer.make(inMemory: true)
        let settings = SyncSettings(suiteName: "test.\(UUID().uuidString)")
        let remote = FakeSyncRemote()
        let child = try await ChildStore(modelContainer: container).addChild(name: "Cal", colorTag: "sage")
        let before = try await LogStore(modelContainer: container).log(.itchEpisode, child: child.id, source: .widget, loggedBy: "You")
        let other = try await LogStore(modelContainer: container).log(.flare, child: child.id, source: .app, loggedBy: "Grandma")

        await remote.setMembers(2)
        try await SyncEngine(modelContainer: container, remote: remote, settings: settings)
            .sync(userID: UUID(), displayName: "Dad")

        #expect(await remote.logs[before.id]?.loggedBy == "Dad")
        #expect(await remote.logs[other.id]?.loggedBy == "Grandma", "only pre-account logs are claimed")
        #expect(settings.householdSize == 2)
        settings.reset()
        #expect(settings.householdSize == 1)
    }
}

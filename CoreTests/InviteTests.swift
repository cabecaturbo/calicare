import Core
import Foundation
import SwiftData
import Testing

struct InviteCodeTests {
    @Test(arguments: ["ABC234", "abc234", "abc 234", "ABC-234", " a b c 2 3 4 "])
    func typedCodesAreCleanedUp(_ typed: String) {
        #expect(InviteCode(typed)?.value == "ABC234")
    }

    @Test(arguments: ["ABC23", "ABC2345", "ABC0O1", "ABCI23", ""])
    func impossibleCodesAreRefused(_ typed: String) {
        #expect(InviteCode(typed) == nil)
    }

    @Test func readsInTwoHalves() {
        #expect(InviteCode("ABC234")?.description == "ABC 234")
    }

    @Test func shareMessageSaysWhatToDo() throws {
        let code = try #require(InviteCode("ABC234"))
        let expires = TestTime.date(2026, 10, 3, 12)
        let message = code.shareMessage(childName: "Cal", role: .partner, expires: expires, locale: Locale(identifier: "en_US"))
        #expect(message.contains("log Cal's day together"))
        #expect(message.contains("ABC 234"))
        #expect(message.contains("Oct 3"))
        #expect(code.shareMessage(childName: nil, role: .caregiver, expires: expires).contains("help log our day"))
    }

    @Test func rolesMatchTheServer() {
        #expect(InviteRole.partner.memberRole == "owner")
        #expect(InviteRole.caregiver.memberRole == "caregiver")
    }
}

struct JoinHouseholdTests {
    @Test func joiningQueuesEverythingForTheNewHousehold() async throws {
        let container = try CaliCareModelContainer.make(inMemory: true)
        let settings = SyncSettings(suiteName: "test.\(UUID().uuidString)")
        let remote = FakeSyncRemote()
        let engine = SyncEngine(modelContainer: container, remote: remote, settings: settings)
        let user = UUID()

        let child = try await ChildStore(modelContainer: container).addChild(name: "Cal", colorTag: "sage")
        let entry = try await LogStore(modelContainer: container).log(.itchEpisode, child: child.id, source: .app)
        try await engine.sync(userID: user, displayName: "Dad")
        let original = try #require(settings.householdID)
        #expect(try await engine.localRecordCount() == (1, 1))

        let joined = UUID()
        try await engine.join(household: joined, userID: user)
        #expect(settings.householdID == joined)
        #expect(settings.cursor == nil)

        try await engine.sync(userID: user, displayName: "Dad")
        #expect(await remote.logs[entry.id]?.householdID == joined)
        #expect(await remote.children[child.id]?.householdID == joined)
        #expect(original != joined)
    }
}

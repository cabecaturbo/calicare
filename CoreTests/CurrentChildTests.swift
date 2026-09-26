import Core
import Foundation
import Testing

struct CurrentChildTests {
    private func makeSetting() -> CurrentChildSetting {
        let suite = "test.\(UUID().uuidString)"
        return CurrentChildSetting(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func roundTripsAndClears() {
        let setting = makeSetting()
        #expect(setting.childID == nil)
        let id = UUID()
        setting.childID = id
        #expect(setting.childID == id)
        setting.childID = nil
        #expect(setting.childID == nil)
    }

    @Test func resolvesSavedChild() async throws {
        let harness = try await TestHarness()
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")
        let setting = makeSetting()
        setting.childID = sibling.id
        #expect(try await harness.children.currentChild(setting: setting)?.id == sibling.id)
    }

    @Test func fallsBackWhenSavedChildIsDeleted() async throws {
        let harness = try await TestHarness()
        let sibling = try await harness.children.addChild(name: "Leo", colorTag: "clay")
        let setting = makeSetting()
        setting.childID = sibling.id
        try await harness.children.deleteChild(sibling.id)

        #expect(try await harness.children.currentChild(setting: setting)?.id == harness.child.id)
        #expect(try await harness.children.activeChildren().map(\.id) == [harness.child.id])
    }

    @Test func fallsBackWhenNothingSaved() async throws {
        let harness = try await TestHarness()
        #expect(try await harness.children.currentChild(setting: makeSetting())?.id == harness.child.id)
    }
}

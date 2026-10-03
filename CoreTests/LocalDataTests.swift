import Core
import Foundation
import SwiftData
import Testing

struct LocalDataTests {
    @Test func eraseAllRemovesChildrenLogsAndTheCurrentChild() async throws {
        let container = try CaliCareModelContainer.make(inMemory: true)
        let current = CurrentChildSetting.isolated()
        let child = try await ChildStore(modelContainer: container).addChild(name: "Cal", colorTag: "sage")
        current.childID = child.id
        try await LogStore(modelContainer: container).log(.itchEpisode, child: child.id, source: .app)

        try LocalData.eraseAll(container: container, currentChild: current)

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<Child>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<LogEvent>()) == 0)
        #expect(current.childID == nil)
    }
}

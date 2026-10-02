import Core
import Foundation
import Testing

/// Patch tests: the plan's wait, and what's running, ready, or checked.
struct PatchTestsTests {
    @Test func readsHowLongToWait() {
        #expect(PatchTests.wait("24 hours") == 86_400)
        #expect(PatchTests.wait("Patch test on the forearm for 48 hrs first") == 172_800)
        #expect(PatchTests.wait("2 days") == 172_800)
        #expect(PatchTests.wait("24h") == 86_400)
        #expect(PatchTests.wait("before using anything new") == nil)
        #expect(PatchTests.wait(nil) == nil)
    }

    @Test func runningReadyAndChecked() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 19))
        let plan = PlanItemInfo(id: UUID(), planID: UUID(), kind: .topicalStep,
                                text: "Patch test any new product on the inner forearm for 24 hours first.",
                                dose: nil, frequency: nil, timing: nil, duration: "24 hours",
                                sourcePage: 1, sourceLine: nil, isConfirmed: true, order: 0)
        let balm = try await harness.logs.logPatchTest(what: " Calendula balm ", where: "Inner forearm", child: harness.child.id, source: .app)
        #expect(balm.note == "Calendula balm · Inner forearm")
        harness.clock.advance(minutes: 60)
        let oil = try await harness.logs.logPatchTest(what: "Plain oil", where: "", child: harness.child.id, source: .app)
        try await harness.logs.update(oil.id, value: .patch(.noReaction), note: oil.note, timestamp: oil.timestamp)
        let logs = try await harness.logs.allLive()

        let early = PatchTests(items: [plan], logs: logs, now: TestTime.date(27, 9))
        #expect(early.wait == 86_400)
        #expect(early.running.map(\.label) == ["Calendula balm · Inner forearm"])
        #expect(early.running.first?.checkAt == TestTime.date(27, 19))
        #expect(early.running.first?.isReady(at: TestTime.date(27, 9)) == false)
        #expect(early.running.first?.isReady(at: TestTime.date(27, 19)) == true)
        #expect(early.recent.map(\.result) == [.noReaction])
    }
}

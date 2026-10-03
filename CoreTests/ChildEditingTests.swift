import Core
import Foundation
import Testing

/// Editing a child's name, birth date, and color.
struct ChildEditingTests {
    @Test func updateChangesDetailsAndMarksForSync() async throws {
        let harness = try await TestHarness(start: TestTime.date(26, 9))
        harness.clock.advance(minutes: 5)
        let born = TestTime.date(2024, 3, 1, 12)

        let updated = try await harness.children.updateChild(harness.child.id, name: "  Callie ", birthDate: born, colorTag: "clay")

        #expect(updated.name == "Callie")
        #expect(updated.birthDate == born)
        #expect(updated.colorTag == "clay")
        #expect(try await harness.children.activeChildren().map(\.name) == ["Callie"])
    }

    @Test func updateNeedsANameAndALiveChild() async throws {
        let harness = try await TestHarness()
        await #expect(throws: ChildStoreError.emptyName) {
            try await harness.children.updateChild(harness.child.id, name: " ", birthDate: nil, colorTag: "sage")
        }
        await #expect(throws: ChildStoreError.childNotFound) {
            try await harness.children.updateChild(UUID(), name: "Leo", birthDate: nil, colorTag: "sage")
        }
    }
}

import Core
import Foundation
import SwiftData
import Testing

/// The photo timeline: files on this phone only, nothing in the synced database.
struct PhotoLibraryTests {
    private func library() -> (PhotoLibrary, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("photos-\(UUID().uuidString)", isDirectory: true)
        return (PhotoLibrary(root: root, child: UUID()), root)
    }

    @Test func spotsAndPhotosInOrder() throws {
        let (photos, root) = library()
        defer { try? FileManager.default.removeItem(at: root) }
        let elbow = try photos.addSpot(" Left elbow ", now: TestTime.date(20, 9))
        let first = try photos.addPhoto(Data([1, 2, 3]), spot: elbow.id, takenAt: TestTime.date(20, 9))
        let second = try photos.addPhoto(Data([4, 5]), spot: elbow.id, takenAt: TestTime.date(27, 9))

        #expect(try photos.spots().map(\.name) == ["Left elbow"])
        #expect(try photos.photos(spot: elbow.id).map(\.id) == [first.id, second.id])
        #expect(try Data(contentsOf: photos.url(for: second)) == Data([4, 5]))
        #expect(throws: PhotoLibrary.Failure.spotNotFound) { try photos.addPhoto(Data([0]), spot: UUID()) }

        try photos.deleteSpot(elbow.id)
        #expect(try photos.spots().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: photos.url(for: first).path))
    }

    @Test func photosAreExcludedFromBackupAndNeverInTheDatabase() async throws {
        let (photos, root) = library()
        defer { try? FileManager.default.removeItem(at: root) }
        let spot = try photos.addSpot("Cheek")
        try photos.addPhoto(Data([9]), spot: spot.id)
        let values = try photos.folder.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)

        // Nothing about photos is a synced model: the schema has no photo type,
        // and a sync of a store with only photos on disk pushes nothing.
        let models = SchemaV5.models.map { String(describing: $0) }
        #expect(!models.contains { $0.localizedCaseInsensitiveContains("photo") })
        let harness = try await TestHarness()
        let remote = FakeSyncRemote()
        let report = try await SyncEngine(modelContainer: harness.container, remote: remote,
                                          settings: SyncSettings(suiteName: "test.\(UUID().uuidString)"))
            .sync(userID: UUID(), displayName: "Mom")
        #expect(report.pushedLogs == 0)
        #expect(report.pushedChildren == 1)
    }
}

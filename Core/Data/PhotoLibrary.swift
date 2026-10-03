import Foundation

/// The photo timeline's storage (prompt 6.1): files in a folder on this phone
/// only, with a small JSON index. Never in the synced database, excluded from
/// iCloud backup, and never sent anywhere. Children's photos never leave the phone.
public struct PhotoLibrary: Sendable {
    public struct Spot: Codable, Hashable, Sendable, Identifiable {
        public let id: UUID
        public var name: String
        public let createdAt: Date
    }

    public struct Photo: Codable, Hashable, Sendable, Identifiable {
        public let id: UUID
        public let spotID: UUID
        public let takenAt: Date
        public let fileName: String
    }

    struct Index: Codable {
        var spots: [Spot] = []
        var photos: [Photo] = []
    }

    public enum Failure: Error, Equatable {
        case emptyName, spotNotFound
    }

    /// One folder per child.
    public let folder: URL

    public init(root: URL, child childID: UUID) {
        folder = root.appendingPathComponent(childID.uuidString, isDirectory: true)
    }

    /// The app's photo folder: Application Support/Photos, excluded from backup.
    public static func appRoot() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Photos", isDirectory: true)
    }

    public func spots() throws -> [Spot] {
        try load().spots.sorted { $0.createdAt < $1.createdAt }
    }

    /// A spot's photos, oldest first.
    public func photos(spot spotID: UUID) throws -> [Photo] {
        try load().photos.filter { $0.spotID == spotID }.sorted { $0.takenAt < $1.takenAt }
    }

    @discardableResult
    public func addSpot(_ name: String, now: Date = .now) throws -> Spot {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw Failure.emptyName }
        var index = try load()
        let spot = Spot(id: UUID(), name: String(clean.prefix(60)), createdAt: now)
        index.spots.append(spot)
        try save(index)
        return spot
    }

    /// Saves JPEG data for a spot.
    @discardableResult
    public func addPhoto(_ jpeg: Data, spot spotID: UUID, takenAt: Date = .now) throws -> Photo {
        var index = try load()
        guard index.spots.contains(where: { $0.id == spotID }) else { throw Failure.spotNotFound }
        let photo = Photo(id: UUID(), spotID: spotID, takenAt: takenAt, fileName: "\(UUID().uuidString).jpg")
        try prepareFolder()
        try jpeg.write(to: url(for: photo), options: [.atomic, .completeFileProtection])
        index.photos.append(photo)
        try save(index)
        return photo
    }

    public func url(for photo: Photo) -> URL {
        folder.appendingPathComponent(photo.fileName)
    }

    public func deletePhoto(_ id: UUID) throws {
        var index = try load()
        if let photo = index.photos.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(at: url(for: photo))
        }
        index.photos.removeAll { $0.id == id }
        try save(index)
    }

    /// Removes a spot and all its photos.
    public func deleteSpot(_ id: UUID) throws {
        var index = try load()
        for photo in index.photos where photo.spotID == id {
            try? FileManager.default.removeItem(at: url(for: photo))
        }
        index.photos.removeAll { $0.spotID == id }
        index.spots.removeAll { $0.id == id }
        try save(index)
    }

    // MARK: - Files

    private var indexURL: URL { folder.appendingPathComponent("index.json") }

    private func load() throws -> Index {
        guard let data = try? Data(contentsOf: indexURL) else { return Index() }
        return try JSONDecoder().decode(Index.self, from: data)
    }

    private func save(_ index: Index) throws {
        try prepareFolder()
        try JSONEncoder().encode(index).write(to: indexURL, options: [.atomic, .completeFileProtection])
    }

    private func prepareFolder() throws {
        guard !FileManager.default.fileExists(atPath: folder.path) else { return }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var root = folder.deletingLastPathComponent()
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? root.setResourceValues(values)
        var mine = folder
        try? mine.setResourceValues(values)
    }
}

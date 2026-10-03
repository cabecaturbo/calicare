import Foundation
import SwiftData
import Synchronization

/// Builds the one SwiftData container shared by the app, widgets, and intents.
public enum CaliCareModelContainer {
    private static let cache = Mutex<ModelContainer?>(nil)

    /// The process-wide container stored in the App Group. Safe to call from any thread.
    public static func shared() throws -> ModelContainer {
        try cache.withLock { cached in
            if let cached { return cached }
            let container = try openRetrying()
            cached = container
            return container
        }
    }

    /// Right after an update, the app and a widget can open the shared store at
    /// the same moment, and one of them finds it mid-migration ("store version
    /// hashes didn't migrate"). A moment later the other has finished, so try again.
    private static func openRetrying(attempts: Int = 4) throws -> ModelContainer {
        var attempt = 1
        while true {
            do {
                return try make()
            } catch {
                guard attempt < attempts else { throw error }
                attempt += 1
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
    }

    /// A new container. Use `inMemory` for tests and previews.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV6.self)
        let configuration = inMemory
            ? ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(
                "CaliCare",
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .none
            )
        return try ModelContainer(
            for: schema,
            migrationPlan: CaliCareMigrationPlan.self,
            configurations: configuration
        )
    }

    /// A container stored at `url`, for migration tests.
    public static func make(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV6.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: CaliCareMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
    }
}

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
            let container = try make()
            cached = container
            return container
        }
    }

    /// A new container. Use `inMemory` for tests and previews.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
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
}

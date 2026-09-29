import SwiftData

/// Add each new schema version and its stage here. Never edit a shipped version.
public enum CaliCareMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    public static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3]
    }

    /// V2 only adds optional fields and the RoutineStep model.
    static let v1ToV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)

    /// V3 adds the care plan models and RoutineStep's optional planItemID.
    static let v2ToV3 = MigrationStage.lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)
}

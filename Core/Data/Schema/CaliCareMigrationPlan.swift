import SwiftData

/// Add each new schema version and its stage here. Never edit a shipped version.
public enum CaliCareMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self]
    }

    public static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3, v3ToV4, v4ToV5, v5ToV6, v6ToV7]
    }

    /// V2 only adds optional fields and the RoutineStep model.
    static let v1ToV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)

    /// V3 adds the care plan models and RoutineStep's optional planItemID.
    static let v2ToV3 = MigrationStage.lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)

    /// V4 adds the Food model.
    static let v3ToV4 = MigrationStage.lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)

    /// V5 adds the Product model.
    static let v4ToV5 = MigrationStage.lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self)

    /// V6 adds optional wording fields to RoutineStep and PlanItem.
    static let v5ToV6 = MigrationStage.lightweight(fromVersion: SchemaV5.self, toVersion: SchemaV6.self)

    /// V7 adds optional supplement and wording fields to PlanItem.
    static let v6ToV7 = MigrationStage.lightweight(fromVersion: SchemaV6.self, toVersion: SchemaV7.self)
}

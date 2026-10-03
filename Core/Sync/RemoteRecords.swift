import Foundation

/// A child as stored in Supabase (`children`). See supabase/README.md.
public struct RemoteChild: Codable, Equatable, Sendable {
    public var id: UUID
    public var householdID: UUID
    public var name: String
    public var birthDate: Date?
    public var colorTag: String
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    /// Set by the server; nil on the way up.
    public var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case householdID = "household_id"
        case birthDate = "birth_date"
        case colorTag = "color_tag"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    public init(
        id: UUID, householdID: UUID, name: String, birthDate: Date?, colorTag: String, isActive: Bool,
        createdAt: Date, updatedAt: Date, deletedAt: Date?, serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.householdID = householdID
        self.name = name
        self.birthDate = birthDate
        self.colorTag = colorTag
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    // Always send deleted_at and birth_date, even when nil, so clearing them syncs.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdID, forKey: .householdID)
        try c.encode(name, forKey: .name)
        try c.encode(birthDate, forKey: .birthDate)
        try c.encode(colorTag, forKey: .colorTag)
        try c.encode(isActive, forKey: .isActive)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

/// A log as stored in Supabase (`log_events`). Raw strings, like the app's model,
/// so a type from a newer app version passes through untouched.
public struct RemoteLogEvent: Codable, Equatable, Sendable {
    public var id: UUID
    public var householdID: UUID
    public var childID: UUID?
    public var type: String
    public var value: String?
    public var note: String?
    public var occurredAt: Date
    public var loggedBy: String
    public var entrySource: String
    /// Where a flare was, as `BodyArea` raw values. Empty when not given.
    public var bodyAreas: [String]
    public var routineStepID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, value, note
        case householdID = "household_id"
        case childID = "child_id"
        case occurredAt = "occurred_at"
        case loggedBy = "logged_by"
        case entrySource = "entry_source"
        case bodyAreas = "body_areas"
        case routineStepID = "routine_step_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    public init(
        id: UUID, householdID: UUID, childID: UUID?, type: String, value: String?, note: String?,
        occurredAt: Date, loggedBy: String, entrySource: String,
        bodyAreas: [String] = [], routineStepID: UUID? = nil,
        createdAt: Date, updatedAt: Date, deletedAt: Date?, serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.householdID = householdID
        self.childID = childID
        self.type = type
        self.value = value
        self.note = note
        self.occurredAt = occurredAt
        self.loggedBy = loggedBy
        self.entrySource = entrySource
        self.bodyAreas = bodyAreas
        self.routineStepID = routineStepID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    // The U2 columns may be missing from rows read before the migration.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        householdID = try c.decode(UUID.self, forKey: .householdID)
        childID = try c.decodeIfPresent(UUID.self, forKey: .childID)
        type = try c.decode(String.self, forKey: .type)
        value = try c.decodeIfPresent(String.self, forKey: .value)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        occurredAt = try c.decode(Date.self, forKey: .occurredAt)
        loggedBy = try c.decode(String.self, forKey: .loggedBy)
        entrySource = try c.decode(String.self, forKey: .entrySource)
        bodyAreas = try c.decodeIfPresent([String].self, forKey: .bodyAreas) ?? []
        routineStepID = try c.decodeIfPresent(UUID.self, forKey: .routineStepID)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        serverUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .serverUpdatedAt)
    }

    // Always send nullable columns, so clearing a note or undoing a delete syncs.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdID, forKey: .householdID)
        try c.encode(childID, forKey: .childID)
        try c.encode(type, forKey: .type)
        try c.encode(value, forKey: .value)
        try c.encode(note, forKey: .note)
        try c.encode(occurredAt, forKey: .occurredAt)
        try c.encode(loggedBy, forKey: .loggedBy)
        try c.encode(entrySource, forKey: .entrySource)
        try c.encode(bodyAreas, forKey: .bodyAreas)
        try c.encode(routineStepID, forKey: .routineStepID)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

/// A routine step as stored in Supabase (`routine_steps`).
public struct RemoteRoutineStep: Codable, Equatable, Sendable {
    public var id: UUID
    public var householdID: UUID
    public var childID: UUID
    public var name: String
    /// "morning" or "evening", raw like the app's model.
    public var time: String
    public var sortOrder: Int
    public var isActive: Bool
    /// The care plan item that made this step, if any.
    public var planItemID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, time
        case householdID = "household_id"
        case childID = "child_id"
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case planItemID = "plan_item_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    public init(
        id: UUID, householdID: UUID, childID: UUID, name: String, time: String, sortOrder: Int, isActive: Bool,
        planItemID: UUID? = nil, createdAt: Date, updatedAt: Date, deletedAt: Date?, serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.householdID = householdID
        self.childID = childID
        self.name = name
        self.time = time
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.planItemID = planItemID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    // Always send deleted_at, even when nil, so restoring a step syncs.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdID, forKey: .householdID)
        try c.encode(childID, forKey: .childID)
        try c.encode(name, forKey: .name)
        try c.encode(time, forKey: .time)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(isActive, forKey: .isActive)
        try c.encode(planItemID, forKey: .planItemID)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

/// What changed on the server since a cursor.
public struct RemoteChanges: Sendable, Equatable {
    public var children: [RemoteChild]
    public var logs: [RemoteLogEvent]
    public var routineSteps: [RemoteRoutineStep]
    public var carePlans: [RemoteCarePlan]
    public var planItems: [RemotePlanItem]
    public var visits: [RemoteVisit]
    public var foods: [RemoteFood]

    public init(children: [RemoteChild] = [], logs: [RemoteLogEvent] = [], routineSteps: [RemoteRoutineStep] = [],
                carePlans: [RemoteCarePlan] = [], planItems: [RemotePlanItem] = [], visits: [RemoteVisit] = [],
                foods: [RemoteFood] = []) {
        self.children = children
        self.logs = logs
        self.routineSteps = routineSteps
        self.carePlans = carePlans
        self.planItems = planItems
        self.visits = visits
        self.foods = foods
    }

    /// The newest server time seen: the next "changes since" cursor.
    public var latestServerTime: Date? {
        (children.compactMap(\.serverUpdatedAt) + logs.compactMap(\.serverUpdatedAt)
            + routineSteps.compactMap(\.serverUpdatedAt) + carePlans.compactMap(\.serverUpdatedAt)
            + planItems.compactMap(\.serverUpdatedAt) + visits.compactMap(\.serverUpdatedAt)
            + foods.compactMap(\.serverUpdatedAt)).max()
    }
}

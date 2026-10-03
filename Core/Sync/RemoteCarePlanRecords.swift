import Foundation

/// A started or ended care plan as stored in Supabase (`care_plans`).
/// Drafts and the original file's name never leave the phone.
public struct RemoteCarePlan: Codable, Equatable, Sendable {
    public var id: UUID
    public var householdID: UUID
    public var childID: UUID
    public var provider: String
    public var planDate: Date?
    public var status: String
    public var startedAt: Date?
    public var endedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, provider, status
        case householdID = "household_id"
        case childID = "child_id"
        case planDate = "plan_date"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    public init(id: UUID, householdID: UUID, childID: UUID, provider: String, planDate: Date?, status: String,
                startedAt: Date?, endedAt: Date?, createdAt: Date, updatedAt: Date, deletedAt: Date?,
                serverUpdatedAt: Date? = nil) {
        self.id = id
        self.householdID = householdID
        self.childID = childID
        self.provider = provider
        self.planDate = planDate
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    // Always send the optional dates, even when nil, so clearing them syncs.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdID, forKey: .householdID)
        try c.encode(childID, forKey: .childID)
        try c.encode(provider, forKey: .provider)
        try c.encode(planDate, forKey: .planDate)
        try c.encode(status, forKey: .status)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(endedAt, forKey: .endedAt)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

/// A confirmed plan item as stored in Supabase (`plan_items`).
public struct RemotePlanItem: Codable, Equatable, Sendable {
    public var id: UUID
    public var householdID: UUID
    public var planID: UUID
    public var childID: UUID
    public var kind: String
    public var text: String
    public var dose: String?
    public var frequency: String?
    public var timing: String?
    public var duration: String?
    public var sourcePage: Int?
    public var sourceLine: String?
    public var sortOrder: Int
    /// Wording (SchemaV6).
    public var label: String?
    public var detail: String?
    public var category: String?
    public var parentItemID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, text, dose, frequency, timing, duration, label, detail, category
        case parentItemID = "parent_item_id"
        case householdID = "household_id"
        case planID = "plan_id"
        case childID = "child_id"
        case sourcePage = "source_page"
        case sourceLine = "source_line"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    public init(id: UUID, householdID: UUID, planID: UUID, childID: UUID, kind: String, text: String,
                dose: String?, frequency: String?, timing: String?, duration: String?,
                sourcePage: Int?, sourceLine: String?, sortOrder: Int,
                createdAt: Date, updatedAt: Date, deletedAt: Date?, serverUpdatedAt: Date? = nil) {
        self.id = id
        self.householdID = householdID
        self.planID = planID
        self.childID = childID
        self.kind = kind
        self.text = text
        self.dose = dose
        self.frequency = frequency
        self.timing = timing
        self.duration = duration
        self.sourcePage = sourcePage
        self.sourceLine = sourceLine
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdID, forKey: .householdID)
        try c.encode(planID, forKey: .planID)
        try c.encode(childID, forKey: .childID)
        try c.encode(kind, forKey: .kind)
        try c.encode(text, forKey: .text)
        try c.encode(dose, forKey: .dose)
        try c.encode(frequency, forKey: .frequency)
        try c.encode(timing, forKey: .timing)
        try c.encode(duration, forKey: .duration)
        try c.encode(sourcePage, forKey: .sourcePage)
        try c.encode(sourceLine, forKey: .sourceLine)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(label, forKey: .label)
        try c.encode(detail, forKey: .detail)
        try c.encode(category, forKey: .category)
        try c.encode(parentItemID, forKey: .parentItemID)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

/// A provider visit as stored in Supabase (`visits`).
public struct RemoteVisit: Codable, Equatable, Sendable {
    public var id: UUID
    public var householdID: UUID
    public var childID: UUID
    public var date: Date
    public var provider: String
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, date, provider, notes
        case householdID = "household_id"
        case childID = "child_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    public init(id: UUID, householdID: UUID, childID: UUID, date: Date, provider: String, notes: String?,
                createdAt: Date, updatedAt: Date, deletedAt: Date?, serverUpdatedAt: Date? = nil) {
        self.id = id
        self.householdID = householdID
        self.childID = childID
        self.date = date
        self.provider = provider
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdID, forKey: .householdID)
        try c.encode(childID, forKey: .childID)
        try c.encode(date, forKey: .date)
        try c.encode(provider, forKey: .provider)
        try c.encode(notes, forKey: .notes)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

/// A food on a child's list, as stored in Supabase (`foods`).
public struct RemoteFood: Codable, Equatable, Sendable {
    public var id: UUID
    public var householdID: UUID
    public var childID: UUID
    public var name: String
    public var family: String?
    public var status: String
    public var statusChangedAt: Date
    public var decidedBy: String
    public var note: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, family, status, note
        case householdID = "household_id"
        case childID = "child_id"
        case statusChangedAt = "status_changed_at"
        case decidedBy = "decided_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    public init(id: UUID, householdID: UUID, childID: UUID, name: String, family: String?, status: String,
                statusChangedAt: Date, decidedBy: String, note: String?, createdAt: Date, updatedAt: Date,
                deletedAt: Date?, serverUpdatedAt: Date? = nil) {
        self.id = id
        self.householdID = householdID
        self.childID = childID
        self.name = name
        self.family = family
        self.status = status
        self.statusChangedAt = statusChangedAt
        self.decidedBy = decidedBy
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdID, forKey: .householdID)
        try c.encode(childID, forKey: .childID)
        try c.encode(name, forKey: .name)
        try c.encode(family, forKey: .family)
        try c.encode(status, forKey: .status)
        try c.encode(statusChangedAt, forKey: .statusChangedAt)
        try c.encode(decidedBy, forKey: .decidedBy)
        try c.encode(note, forKey: .note)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

/// A product in a child's diary, as stored in Supabase (`products`).
public struct RemoteProduct: Codable, Equatable, Sendable {
    public var id: UUID
    public var householdID: UUID
    public var childID: UUID
    public var name: String
    public var category: String
    public var startedAt: Date
    public var stoppedAt: Date?
    public var neverAgain: Bool
    public var reason: String?
    public var restockEveryDays: Int?
    public var restockedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, category, reason
        case householdID = "household_id"
        case childID = "child_id"
        case startedAt = "started_at"
        case stoppedAt = "stopped_at"
        case neverAgain = "never_again"
        case restockEveryDays = "restock_every_days"
        case restockedAt = "restocked_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    public init(id: UUID, householdID: UUID, childID: UUID, name: String, category: String, startedAt: Date,
                stoppedAt: Date?, neverAgain: Bool, reason: String?, restockEveryDays: Int?, restockedAt: Date?,
                createdAt: Date, updatedAt: Date, deletedAt: Date?, serverUpdatedAt: Date? = nil) {
        self.id = id
        self.householdID = householdID
        self.childID = childID
        self.name = name
        self.category = category
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.neverAgain = neverAgain
        self.reason = reason
        self.restockEveryDays = restockEveryDays
        self.restockedAt = restockedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdID, forKey: .householdID)
        try c.encode(childID, forKey: .childID)
        try c.encode(name, forKey: .name)
        try c.encode(category, forKey: .category)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(stoppedAt, forKey: .stoppedAt)
        try c.encode(neverAgain, forKey: .neverAgain)
        try c.encode(reason, forKey: .reason)
        try c.encode(restockEveryDays, forKey: .restockEveryDays)
        try c.encode(restockedAt, forKey: .restockedAt)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deletedAt, forKey: .deletedAt)
    }
}

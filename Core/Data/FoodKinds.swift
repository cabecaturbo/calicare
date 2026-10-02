import Foundation

/// Where a food stands for a child: decided by the parent or the plan, never by the app.
public enum FoodStatus: String, Codable, Sendable, CaseIterable {
    case safe, testing, paused

    public var title: String {
        switch self {
        case .safe: "Safe"
        case .testing: "Testing"
        case .paused: "Paused"
        }
    }
}

/// Who set a food's status.
public enum FoodDecider: String, Codable, Sendable {
    case plan, parent
}

/// A read-only copy of a food.
public struct FoodInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let childID: UUID
    public let name: String
    public let family: String?
    public let status: FoodStatus
    public let statusChangedAt: Date
    public let decidedBy: FoodDecider
    public let note: String?

    public init(id: UUID, childID: UUID, name: String, family: String?, status: FoodStatus, statusChangedAt: Date,
                decidedBy: FoodDecider, note: String?) {
        self.id = id
        self.childID = childID
        self.name = name
        self.family = family
        self.status = status
        self.statusChangedAt = statusChangedAt
        self.decidedBy = decidedBy
        self.note = note
    }
}

extension FoodInfo {
    init?(_ food: Food) {
        guard let status = food.status, let decidedBy = food.decidedBy else { return nil }
        self.init(id: food.id, childID: food.childID, name: food.name, family: food.family, status: status,
                  statusChangedAt: food.statusChangedAt, decidedBy: decidedBy, note: food.note)
    }
}

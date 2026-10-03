import Foundation

/// What kind of product it is. Things that touch the skin, not treatments.
public enum ProductCategory: String, Codable, Sendable, CaseIterable {
    case moisturizer, wash, laundry, clothing, other

    public var title: String {
        switch self {
        case .moisturizer: "Moisturizer"
        case .wash: "Wash"
        case .laundry: "Laundry"
        case .clothing: "Clothing"
        case .other: "Other"
        }
    }

    /// A best guess from the name ("Free & clear detergent" is laundry), or
    /// nil when the name doesn't say. The parent can always change it.
    public static func guess(from name: String) -> ProductCategory? {
        let words = name.lowercased().split { !$0.isLetter }.map(String.init)
        let table: [(ProductCategory, Set<String>)] = [
            (.laundry, ["detergent", "laundry", "softener", "dryer", "pods"]),
            (.wash, ["wash", "soap", "shampoo", "cleanser", "bath", "bubble"]),
            (.clothing, ["pajamas", "pyjamas", "shirt", "onesie", "sleeves", "mittens", "socks", "sleepsuit",
                         "wrap", "bodysuit", "cotton", "silk", "bamboo", "leggings", "gloves"]),
            (.moisturizer, ["cream", "lotion", "balm", "ointment", "oil", "moisturizer", "moisturiser", "butter",
                            "salve", "emollient", "jelly"]),
        ]
        return table.first { !$0.1.isDisjoint(with: words) }?.0
    }
}

/// A read-only copy of a product.
public struct ProductInfo: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let childID: UUID
    public let name: String
    public let category: ProductCategory
    public let startedAt: Date
    public let stoppedAt: Date?
    public let neverAgain: Bool
    public let reason: String?
    public let restockEveryDays: Int?
    public let restockedAt: Date?
    /// When the parent last changed it; "never again" dates use this.
    public let updatedAt: Date

    public init(id: UUID, childID: UUID, name: String, category: ProductCategory, startedAt: Date, stoppedAt: Date?,
                neverAgain: Bool, reason: String?, restockEveryDays: Int? = nil, restockedAt: Date? = nil,
                updatedAt: Date) {
        self.id = id
        self.childID = childID
        self.name = name
        self.category = category
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.neverAgain = neverAgain
        self.reason = reason
        self.restockEveryDays = restockEveryDays
        self.restockedAt = restockedAt
        self.updatedAt = updatedAt
    }

    /// Still in use: not stopped and not "never again".
    public var inUse: Bool { stoppedAt == nil && !neverAgain }
}

extension ProductInfo {
    init(_ product: Product) {
        self.init(id: product.id, childID: product.childID, name: product.name, category: product.category,
                  startedAt: product.startedAt, stoppedAt: product.stoppedAt, neverAgain: product.neverAgain,
                  reason: product.reason, restockEveryDays: product.restockEveryDays,
                  restockedAt: product.restockedAt, updatedAt: product.updatedAt)
    }
}

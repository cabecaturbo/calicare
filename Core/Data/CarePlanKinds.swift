import Foundation

/// Where a care plan is: being reviewed, running, or finished.
public enum CarePlanStatus: String, Codable, Sendable, CaseIterable {
    case draft, active, ended
}

/// What one plan item is. The plan's own words stay in `text`; the kind only
/// decides where the item shows up (Plan's routine, baths, supplements, …).
public enum PlanItemKind: String, Codable, Sendable, CaseIterable {
    case routineStep, topicalStep, bath, supplement, medication, foodRule, fundamental, followUp

    /// "Routine step", for the review screen.
    public var title: String {
        switch self {
        case .routineStep: "Routine step"
        case .topicalStep: "On the skin"
        case .bath: "Bath"
        case .supplement: "Supplement"
        case .medication: "Medication"
        case .foodRule: "Food"
        case .fundamental: "Everyday basics"
        case .followUp: "Follow-up"
        }
    }
}

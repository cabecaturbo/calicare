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

    /// Details a parent would expect the plan to give for this kind. When the
    /// plan leaves one out, the review screen says so (the same rule as the
    /// parse-care-plan function's grounding.ts).
    public var expectedDetails: [PlanDetail] {
        switch self {
        case .supplement, .medication: [.dose, .frequency]
        case .topicalStep, .bath: [.frequency]
        case .routineStep, .foodRule, .fundamental, .followUp: []
        }
    }
}

/// The optional details of a plan item, set only when the plan states them.
public enum PlanDetail: String, Codable, Sendable, CaseIterable {
    case dose, frequency, timing, duration

    public var title: String {
        switch self {
        case .dose: "Dose"
        case .frequency: "How often"
        case .timing: "When"
        case .duration: "How long"
        }
    }
}

extension PlanItemInfo {
    public func value(_ detail: PlanDetail) -> String? {
        switch detail {
        case .dose: dose
        case .frequency: frequency
        case .timing: timing
        case .duration: duration
        }
    }

    /// Expected details the plan left blank: "Worth asking at your next visit."
    /// Only when the item gives some of them (Vitamin D "daily" but no dose):
    /// a rule like "rotate after 3 weeks" has no dose to miss.
    public var blanks: [PlanDetail] {
        let expected = kind.expectedDetails
        guard expected.contains(where: { value($0) != nil }) else { return [] }
        return expected.filter { value($0) == nil }
    }
}

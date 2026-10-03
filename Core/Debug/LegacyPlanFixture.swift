import Foundation

/// A made-up plan with the same shapes as real imports that read poorly:
/// "Step N:" lines longer than 80 characters, "ADD" supplements, "Continue
/// A, B", "consider" lines, and avoid lines with qualifiers. Used by the
/// LEGACYPLAN design-review seed and the upgrade tests. Not anyone's plan.
public enum LegacyPlanFixture {
    public static let steps: [(name: String, time: RoutineTime)] = [
        ("Wash face", .morning), ("Moisturizer", .morning),
        ("Bath", .evening), ("Moisturizer", .evening), ("Pajamas", .evening),
    ]

    public static let items: [PlanItemDraft] = [
        line(.routineStep, "Aim to support the skin 3-4x per day, when possible.", text: "Support the skin 3-4x per day, when possible",
             frequency: "3-4x per day"),
        line(.topicalStep, "Step 1: Calendula cream, if tolerated. If Cal doesn’t tolerate this step, move straight to Step 3."),
        line(.topicalStep, "Step 2: Plain aloe gel, 95% or more pure. Brand A or Brand B from the pharmacy shelf."),
        line(.topicalStep, "Step 3: Sunflower oil + Coconut oil. Start with 50:50 ratio and work up, as tolerated. Brand C."),
        line(.topicalStep, "Continue a gentle topical routine for 60-90 days past when the skin is clear to keep it calm.",
             duration: "60-90 days past when the skin is clear"),
        line(.topicalStep, "Patch test any new topical on the inner forearm and wait several hours before using it more widely."),
        line(.bath, "Oat bath 3x per week, 10 minutes.", text: "Oat bath", frequency: "3x per week", duration: "10 minutes"),
        line(.supplement, "Continue Vitamin D, Fish Oil"),
        line(.supplement, "ADD Brand D Skin Drops 2.5 ml (50 drops), 2x per day", text: "ADD Brand D Skin Drops",
             dose: "2.5 ml (50 drops)", frequency: "2x per day"),
        line(.supplement, "ADD Brand E Gut Powder 1 teaspoon (5ml), 2x per day", text: "ADD Brand E Gut Powder",
             dose: "1 teaspoon (5ml)", frequency: "2x per day", timing: "Start low and increase slowly. Mix into water.",
             duration: "Can take long-term."),
        line(.supplement, "ADD Herbal Drops by Brand F 8 drops, 3x daily", text: "ADD Herbal Drops by Brand F",
             dose: "8 drops", frequency: "3x daily", timing: "Start with a single drop, 2x per day and work up slowly."),
        line(.supplement, "Brand G Butyrate is helpful for gut lining support and may be indicated."),
        line(.supplement, "Next Steps: Consider adding Brand H Immune Powder to further support immune function."),
        line(.supplement, "Transition to Brand J Chewables for a multi-vitamin."),
        line(.foodRule, "Avoid confirmed allergens and triggers."),
        line(.foodRule, "Avoid inflammatory foods including dairy, gluten, eggs, soy and nuts."),
        line(.foodRule, "Avoid artificial sugar and processed foods as much as possible. Buy organic when able."),
        line(.followUp, "A follow up consult after 4-6 weeks is helpful.", text: "Follow up consult after 4-6 weeks"),
    ]

    /// Plain words for some lines, keyed by the start of the provider's line.
    /// Each keeps every number and brand of its line (they pass `PlainWords.isFaithful`).
    public static let plain: [String: String] = [
        "Step 1: Calendula": "This is Step 1. Use it if Cal's skin is OK with it. If Cal doesn't like it, skip to Step 3.",
        "Step 2: Plain aloe": "This is Step 2. Use one that is 95% pure or more. Brand A or Brand B, from the drug store.",
        "Step 3: Sunflower": "Start with a 50:50 mix of Sunflower oil and Coconut oil. Use more as the skin allows. Brand C. This is Step 3.",
        "ADD Brand E": "Give 1 teaspoon (5ml) of Brand E Gut Powder, 2x a day. Start low. Go up slowly. Mix it in water.",
        "Patch test": "Put a little of the new thing on the inside of the arm. Wait a few hours. Then look at the skin.",
    ]

    /// Foods on the list, for the food counts.
    public static let safeFoods = ["Oats", "Rice", "Carrot", "Apple", "Chicken", "Sweet potato"]

    private static func line(_ kind: PlanItemKind, _ source: String, text: String? = nil, dose: String? = nil,
                             frequency: String? = nil, timing: String? = nil, duration: String? = nil) -> PlanItemDraft {
        let plain = source.hasSuffix(".") ? String(source.dropLast()) : source
        return PlanItemDraft(kind: kind, text: text ?? plain, dose: dose, frequency: frequency, timing: timing,
                             duration: duration, sourcePage: 1, sourceLine: source)
    }
}

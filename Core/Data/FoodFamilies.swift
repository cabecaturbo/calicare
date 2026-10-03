import Foundation

/// A built-in starting point for food families (for rotation by family).
/// It only fills in a family when a food is added; the parent can change it.
public enum FoodFamilies {
    public static let table: [String: [String]] = [
        "Grasses (grains)": ["wheat", "rice", "oat", "oats", "corn", "barley", "rye", "millet", "sorghum", "bread", "pasta"],
        "Nightshades": ["tomato", "potato", "pepper", "bell pepper", "eggplant", "paprika"],
        "Legumes": ["peanut", "pea", "bean", "green bean", "lentil", "chickpea", "soy", "tofu", "edamame"],
        "Cabbage family": ["broccoli", "cabbage", "kale", "cauliflower", "brussels sprout", "radish", "arugula", "bok choy", "turnip"],
        "Gourds": ["cucumber", "zucchini", "squash", "pumpkin", "melon", "cantaloupe", "watermelon"],
        "Rose family": ["apple", "pear", "strawberry", "cherry", "peach", "plum", "apricot", "raspberry", "blackberry", "almond"],
        "Citrus": ["orange", "lemon", "lime", "grapefruit", "clementine", "mandarin"],
        "Carrot family": ["carrot", "celery", "parsnip", "parsley", "dill", "cilantro", "fennel"],
        "Goosefoot": ["spinach", "beet", "chard", "quinoa"],
        "Poultry": ["chicken", "turkey", "egg", "duck"],
        "Bovine": ["beef", "dairy", "milk", "cheese", "yogurt", "butter", "cream"],
        "Fish": ["salmon", "cod", "tuna", "trout", "sardine", "halibut"],
        "Banana family": ["banana", "plantain"],
        "Heath family": ["blueberry", "cranberry"],
        "Onion family": ["onion", "garlic", "leek", "chive", "asparagus"],
        "Cashew family": ["cashew", "mango", "pistachio"],
        "Grape family": ["grape", "raisin"],
        "Laurel family": ["avocado", "cinnamon"],
        "Sunflower family": ["sunflower seed", "lettuce", "artichoke"],
        "Pork": ["pork", "bacon", "ham"],
        "Morning glory family": ["sweet potato", "yam"],
        "Mint family": ["basil", "mint", "oregano", "rosemary", "thyme", "sage", "chia"],
        "Lamb and goat": ["lamb", "goat", "goat milk", "goat cheese"],
        "Coconut (palm)": ["coconut", "date"],
    ]

    /// The family for a food's name, if the table knows it ("Eggs" → Poultry).
    public static func family(for name: String) -> String? {
        let key = normalized(name)
        for (family, foods) in table where foods.contains(key) {
            return family
        }
        return nil
    }

    public static var names: [String] { table.keys.sorted() }

    /// Lowercase, trimmed, simple plurals made singular ("Blueberries" → "blueberry").
    static func normalized(_ name: String) -> String {
        var key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasSuffix("ies") { key = String(key.dropLast(3)) + "y" }
        else if key.hasSuffix("oes") { key = String(key.dropLast(2)) }
        else if key.hasSuffix("s"), !key.hasSuffix("ss"), key != "oats" { key = String(key.dropLast()) }
        return key
    }
}

/// Foods a care plan names to avoid ("Avoid: dairy, eggs, peanuts"), so the
/// parent can add them as paused in one tap. Only what the plan wrote.
public enum PlanFoods {
    /// One thing to avoid, as the plan wrote it, and any softening words
    /// ("as much as possible", "Buy organic when able") kept apart.
    public struct AvoidLine: Equatable, Sendable, Identifiable {
        public let name: String
        public let qualifier: String?
        /// False for groups that aren't one food ("Confirmed allergens and triggers").
        public let isFood: Bool
        public var id: String { name }
    }

    /// Words that soften a line rather than name a food.
    static let qualifiers = ["as much as possible", "when possible", "if possible", "where possible", "when able", "if able"]
    /// Lines naming a group, not foods: kept whole.
    static let groupOpeners = ["confirmed", "known", "any ", "all "]

    public static func avoidedLines(in items: [PlanItemInfo]) -> [AvoidLine] {
        var lines: [AvoidLine] = []
        for item in items where item.kind == .foodRule {
            guard let range = item.text.range(of: "avoid", options: .caseInsensitive) else { continue }
            var rest = item.text[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespaces))
            // A second sentence ("Buy organic when able") is a note, not a food.
            var notes: [String] = []
            if let stop = rest.range(of: ". ") {
                notes.append(String(rest[stop.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: ". ")))
                rest = String(rest[..<stop.lowerBound])
            }
            rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            for phrase in qualifiers {
                if let found = rest.range(of: phrase, options: .caseInsensitive) {
                    notes.insert(String(rest[found]), at: 0)
                    rest.removeSubrange(found)
                    rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
                }
            }
            // "inflammatory foods including dairy, gluten" → the named foods.
            for lead in [" including ", " like ", " such as "] {
                if let found = rest.range(of: lead, options: .caseInsensitive) { rest = String(rest[found.upperBound...]) }
            }
            let qualifier = notes.filter { !$0.isEmpty }.joined(separator: " · ")
            let lower = rest.lowercased()
            let parts: [String]
            if groupOpeners.contains(where: lower.hasPrefix) {
                parts = [rest]
            } else {
                parts = rest.replacingOccurrences(of: " and ", with: ", ").replacingOccurrences(of: " or ", with: ", ")
                    .split(whereSeparator: { ",;".contains($0) }).map(String.init)
            }
            let isFood = !groupOpeners.contains(where: lower.hasPrefix)
            for part in parts {
                let name = part.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
                guard !name.isEmpty, !lines.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
                lines.append(AvoidLine(name: name.prefix(1).uppercased() + name.dropFirst(),
                                       qualifier: qualifier.isEmpty ? nil : qualifier, isFood: isFood))
            }
        }
        return lines
    }

    /// The foods to avoid, for "Add them as paused".
    public static func avoided(in items: [PlanItemInfo]) -> [String] {
        avoidedLines(in: items).filter(\.isFood).map(\.name)
    }
}

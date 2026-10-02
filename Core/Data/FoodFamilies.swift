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
    public static func avoided(in items: [PlanItemInfo]) -> [String] {
        var names: [String] = []
        for item in items where item.kind == .foodRule {
            let text = item.text
            guard let range = text.range(of: "avoid", options: .caseInsensitive) else { continue }
            let rest = text[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespaces))
            for part in rest.replacingOccurrences(of: " and ", with: ", ").split(whereSeparator: { ",;".contains($0) }) {
                let name = part.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
                if !name.isEmpty, !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                    names.append(name.prefix(1).uppercased() + name.dropFirst())
                }
            }
        }
        return names
    }
}

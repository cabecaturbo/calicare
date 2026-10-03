import Foundation

/// What may be less covered when food groups are paused (prompt 5.6). It
/// names nutrients and suggests asking the provider or a dietitian; it never
/// suggests a supplement or a food to add.
public enum NutrientCoverage {
    /// Food groups and what they usually bring. Matched on whole words, plurals tolerated.
    static let groups: [(words: [String], nutrients: [String])] = [
        (["dairy", "milk", "cheese", "yogurt"], ["calcium", "vitamin D"]),
        (["egg"], ["protein", "choline"]),
        (["fish", "salmon", "tuna", "cod", "sardine"], ["omega-3 fats", "iodine"]),
        (["wheat", "gluten", "grain", "oat", "rice", "barley"], ["fiber", "B vitamins"]),
        (["beef", "meat", "red meat", "lamb", "pork"], ["iron", "zinc", "vitamin B12"]),
        (["chicken", "poultry", "turkey"], ["protein"]),
        (["nut", "peanut", "almond", "cashew", "walnut", "seed"], ["healthy fats", "vitamin E"]),
        (["soy", "legume", "bean", "lentil", "chickpea"], ["protein", "iron", "fiber"]),
        (["citrus", "orange", "lemon"], ["vitamin C"]),
    ]

    /// Nutrients that may be less covered by the paused foods, in a stable order.
    public static func lessCovered(paused: [String]) -> [String] {
        var result: [String] = []
        for food in paused {
            let name = food.lowercased()
            for group in groups where group.words.contains(where: { matches(name, $0) }) {
                for nutrient in group.nutrients where !result.contains(nutrient) { result.append(nutrient) }
            }
        }
        return result
    }

    /// "With dairy and eggs paused, calcium, vitamin D, protein, and choline may be less covered. Worth asking your provider or a dietitian."
    public static func sentence(paused: [String]) -> String? {
        let nutrients = lessCovered(paused: paused)
        guard !nutrients.isEmpty else { return nil }
        let foods = list(paused.map { $0.lowercased() })
        return "With \(foods) paused, \(list(nutrients)) may be less covered. Worth asking your provider or a dietitian."
    }

    private static func matches(_ name: String, _ word: String) -> Bool {
        name.range(of: "\\b\(word)(s|es)?\\b", options: .regularExpression) != nil
    }

    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
    }
}

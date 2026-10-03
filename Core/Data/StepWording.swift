import Foundation

/// What a step is about. Each has a verb and a regular-weight SF Symbol.
public enum StepCategory: String, Codable, Sendable, CaseIterable {
    case wash, apply, give, feed, dress

    public var title: String {
        switch self {
        case .wash: "Wash"
        case .apply: "Apply"
        case .give: "Give"
        case .feed: "Feed"
        case .dress: "Dress"
        }
    }

    /// The verb a label starts with when the plan's words don't have one.
    public var verb: String {
        switch self {
        case .wash: "Wash"
        case .apply: "Apply"
        case .give: "Give"
        case .feed: "Feed"
        case .dress: "Put on"
        }
    }

    public var symbol: String {
        switch self {
        case .wash: "drop"
        case .apply: "hand.point.up.left"
        case .give: "pills"
        case .feed: "fork.knife"
        case .dress: "tshirt"
        }
    }
}

/// A task is ticked off; a note ("3-4x per day", "for 60-90 days") is information.
public enum StepKind: String, Codable, Sendable {
    case task, note
}

/// Short wording for a step, made only from the plan's own words.
public struct StepWording: Equatable, Sendable {
    /// Nil when no short label could be made from the words; the parent can name it.
    public var label: String?
    public var detail: String?
    public var category: StepCategory?
    public var kind: StepKind
    public var timesPerDay: Int?

    public init(label: String?, detail: String?, category: StepCategory?, kind: StepKind, timesPerDay: Int?) {
        self.label = label
        self.detail = detail
        self.category = category
        self.kind = kind
        self.timesPerDay = timesPerDay
    }
}

/// Turns a step's words into a label ("Apply Aloe vera"), detail, category,
/// and kind. Labels start with a verb, are one action, at most 6 words, and
/// never add a number, brand, or ratio the plan didn't write.
public enum StepLabeler {
    public static let maxWords = 6

    /// Verbs a label may start with.
    static let verbs: Set<String> = [
        "apply", "wash", "give", "feed", "put", "take", "rinse", "seal", "bathe", "dress", "offer", "use", "rub",
        "massage", "spray", "soak", "pat", "dry", "brush", "change", "open", "wrap", "cover", "read", "drink", "eat",
        "mix", "add", "check", "trim", "clean", "moisturize", "moisturise", "remove", "start", "soothe", "layer", "dab",
    ]

    /// Single nouns with a natural verb phrase.
    static let phrases: [String: String] = [
        "bath": "Take a bath", "shower": "Take a shower", "pajamas": "Put on pajamas", "pyjamas": "Put on pyjamas",
        "mittens": "Put on mittens", "sleeves": "Put on sleeves",
    ]

    /// Openers that make a line a note, when it also gives a frequency or duration.
    static let noteOpeners: Set<String> = ["support", "continue", "aim", "keep", "repeat"]

    public static func wording(for text: String, planKind: PlanItemKind? = nil, frequency: String? = nil,
                               duration: String? = nil) -> StepWording {
        let clean = clean(text)
        let category = category(for: clean, planKind: planKind)
        let first = clean.split(separator: " ").first.map { $0.lowercased() } ?? ""
        let hasSchedule = frequency != nil || duration != nil || frequencyPhrase(in: clean) != nil
            || clean.range(of: #"\d+\s*[-–]?\s*\d*\s*(days?|weeks?|months?)"#, options: .regularExpression) != nil
        if noteOpeners.contains(first), hasSchedule {
            return StepWording(label: nil, detail: clean, category: category, kind: .note, timesPerDay: nil)
        }
        let (clause, rest) = splitFirstClause(clean)
        var label: String?
        let lead = clause.split(separator: " ").first.map { $0.lowercased() } ?? ""
        if verbs.contains(lead) {
            label = clause
        } else if let phrase = phrases[clause.lowercased()] {
            label = phrase
        } else if let category {
            // "Aloe vera" reads as "aloe vera"; names in capitals ("Active Skin Repair") stay.
            let rest = clause.split(separator: " ").dropFirst()
            let isName = rest.contains { $0.first?.isUppercase == true }
            let noun = isName ? clause : clause.prefix(1).lowercased() + clause.dropFirst()
            label = "\(category.verb) \(noun)"
        }
        if let candidate = label, !isValid(label: candidate, detail: rest, source: clean) { label = nil }
        return StepWording(label: label, detail: label == nil ? nil : rest, category: category, kind: .task,
                           timesPerDay: timesPerDay(frequency ?? frequencyPhrase(in: clean)))
    }

    /// The words without a leading "Step 1:" and outer whitespace.
    public static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: #"^\s*step\s*\d+\s*[:.)-]\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checks a proposed label and detail against the plan's words: a verb
    /// first, one action, at most 6 words, no "Step N:", and every number,
    /// percent, ratio, and capitalised word appears in the source as written.
    public static func isValid(label: String, detail: String?, source: String) -> Bool {
        let words = label.split(separator: " ")
        guard let first = words.first, words.count <= maxWords,
              verbs.contains(first.lowercased()),
              label.range(of: #"^\s*step\s*\d"#, options: [.regularExpression, .caseInsensitive]) == nil,
              !label.contains(". ")
        else { return false }
        // A detail is the plan's words, copied: it must appear in the source as written.
        if let detail, !detail.isEmpty, !source.localizedCaseInsensitiveContains(detail) { return false }
        for token in tokens(in: label, skipFirst: true) + tokens(in: detail ?? "", skipFirst: false)
        where !source.contains(token) {
            return false
        }
        return true
    }

    /// Numbers, percents, ratios, and capitalised words, which must be copied, never made up.
    static func tokens(in text: String, skipFirst: Bool) -> [String] {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "." || $0 == "(" || $0 == ")" })
            .map(String.init)
        return words.enumerated().compactMap { index, word in
            if skipFirst && index == 0 { return nil }
            let hasDigit = word.contains(where: \.isNumber)
            let isCapitalised = word.first?.isUppercase == true && index > 0
            return hasDigit || isCapitalised ? word : nil
        }
    }

    /// "Aloe vera, 96% or more pure. Brand A" → ("Aloe vera", "96% or more pure. Brand A").
    static func splitFirstClause(_ text: String) -> (String, String?) {
        guard let range = text.range(of: #"(,\s|\.\s|;\s|\s[–—-]\s)"#, options: .regularExpression) else {
            let plain = text.hasSuffix(".") ? String(text.dropLast()) : text
            return (plain, nil)
        }
        let rest = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return (String(text[..<range.lowerBound]), rest.isEmpty ? nil : rest)
    }

    static func category(for text: String, planKind: PlanItemKind?) -> StepCategory? {
        let words = Set(text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        let lower = text.lowercased()
        if !words.isDisjoint(with: ["pajamas", "pyjamas", "mittens", "sleeves", "gloves", "socks", "clothes", "dress"]) { return .dress }
        if !words.isDisjoint(with: ["bath", "wash", "face", "shower", "rinse", "bathe", "soak"]) { return .wash }
        if planKind == .supplement || planKind == .medication
            || !words.isDisjoint(with: ["supplement", "supplements", "medicine", "probiotic", "vitamin", "drops", "dose"]) { return .give }
        if planKind == .foodRule || !words.isDisjoint(with: ["breakfast", "lunch", "dinner", "snack", "meal", "feed", "food"]) { return .feed }
        if planKind == .topicalStep || planKind == .routineStep
            || ["cream", "oil", "balm", "aloe", "moistur", "lotion", "ointment", "gel", "apply", "topical", "skin", "wrap", "salve"]
                .contains(where: lower.contains) { return .apply }
        return nil
    }

    /// "3-4x per day", "2x daily", "twice a day", as written.
    public static func frequencyPhrase(in text: String) -> String? {
        let pattern = #"\b\d+(\s*[-–]\s*\d+)?\s*(x|times)\s*(per|a|/)?\s*(day|daily|week)\b"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return String(text[range])
    }

    /// "2x per day" → 2, "3x daily" → 3, "once daily" → 1. Ranges ("3-4x") stay nil.
    public static func timesPerDay(_ frequency: String?) -> Int? {
        guard let text = frequency?.lowercased(), text.contains("day") || text.contains("daily") else { return nil }
        if text.range(of: #"\d+\s*[-–]\s*\d+"#, options: .regularExpression) != nil { return nil }
        if text.contains("once") { return 1 }
        if text.contains("twice") { return 2 }
        if let match = text.firstMatch(of: /(\d+)\s*(?:x|times)/) { return Int(match.1) }
        return nil
    }
}

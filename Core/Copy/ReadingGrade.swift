import Foundation

/// Flesch-Kincaid grade level, for checking that app-written words read at
/// grade 6 or easier. Provider and parent words are never scored.
public enum ReadingGrade {
    public static let limit = 6.0
    /// Below this many words the formula isn't meaningful ("Supplements" alone
    /// scores grade 20), so short labels are checked word by word instead.
    public static let minimumWords = 5
    public static let maxSyllablesInShortLabel = 3

    /// 0.39 × words per sentence + 11.8 × syllables per word − 15.59.
    public static func grade(_ text: String) -> Double {
        let words = words(in: text)
        guard !words.isEmpty else { return 0 }
        let sentences = max(1, text.split(whereSeparator: { ".!?".contains($0) })
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count)
        let syllables = words.map(syllables(in:)).reduce(0, +)
        return 0.39 * Double(words.count) / Double(sentences) + 11.8 * Double(syllables) / Double(words.count) - 15.59
    }

    /// Whether a string reads at grade 6 or easier: Flesch-Kincaid for 5+
    /// words; for shorter labels, no word over 3 syllables (allowlist aside).
    public static func isEasy(_ text: String, allow: Set<String> = allowlist) -> Bool {
        let words = words(in: text)
        if words.count >= minimumWords { return grade(text) <= limit }
        return words.allSatisfy { allow.contains($0.lowercased()) || syllables(in: $0) <= maxSyllablesInShortLabel }
    }

    /// Everyday words that are long but plain.
    public static let allowlist: Set<String> = ["moisturizer", "afternoon", "everything", "notification", "notifications", "caregiver"]

    static func words(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "’" }).map(String.init).filter { $0.contains(where: \.isLetter) }
    }

    /// A vowel-group count with the usual English adjustments; good enough for grading.
    public static func syllables(in word: String) -> Int {
        let w = word.lowercased().filter(\.isLetter)
        guard !w.isEmpty else { return 0 }
        if w.count <= 3 { return 1 }
        let vowels = Set("aeiouy")
        var count = 0
        var previousVowel = false
        for c in w {
            let isVowel = vowels.contains(c)
            if isVowel && !previousVowel { count += 1 }
            previousVowel = isVowel
        }
        if w.hasSuffix("e") && !w.hasSuffix("le") && count > 1 { count -= 1 }
        if w.hasSuffix("es") || w.hasSuffix("ed"), count > 1, !w.hasSuffix("ted"), !w.hasSuffix("ded") { count -= 1 }
        return max(1, count)
    }
}

/// Plain-language versions of the provider's words. They may change wording,
/// never doses, ratios, brands, or conditions.
public enum PlainWords {
    /// Keeps a plain version only if every number, percent, ratio, unit, and
    /// capitalised brand word in the provider's words appears in it unchanged,
    /// it adds no number of its own, and it reads at grade 6 or easier.
    public static func isFaithful(_ plain: String, to source: String) -> Bool {
        let plainTokens = Set(numbers(in: plain))
        guard Set(numbers(in: source)).isSubset(of: plainTokens),
              plainTokens.isSubset(of: Set(numbers(in: source))),
              brands(in: source).allSatisfy({ plain.localizedCaseInsensitiveContains($0) })
        else { return false }
        return ReadingGrade.grade(plain) <= ReadingGrade.limit
    }

    /// "2.5", "50:50", "96%", "5ml".
    static func numbers(in text: String) -> [String] {
        text.matches(of: /\d+(?:[.:\/]\d+)?%?(?:ml|mg|g|oz)?/).map { String($0.output) }
    }

    /// Capitalised words inside a sentence ("Plant Therapy", "Kate Blanc"):
    /// brand and product names. Sentence starts and "I" are skipped.
    static func brands(in text: String) -> [String] {
        var result: [String] = []
        for sentence in text.split(whereSeparator: { ".!?:".contains($0) }) {
            let words = sentence.split(separator: " ").map { $0.trimmingCharacters(in: .punctuationCharacters) }
            for word in words.dropFirst() where word.first?.isUppercase == true && word.count > 1 && word != "I" {
                result.append(word)
            }
        }
        return result
    }

    /// Lowercase, straight quotes, single spaces: for comparing lines.
    public static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

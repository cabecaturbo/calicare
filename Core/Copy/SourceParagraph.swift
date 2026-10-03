import Foundation

/// Finds the provider's whole paragraph in the original plan's text, when the
/// quoted line was cut short. Only ever extends the line; never rewrites it.
public enum SourceParagraph {
    /// The paragraph that starts with `line`, when it's longer than `line`
    /// and doesn't run into another item's line. Nil otherwise.
    public static func find(_ line: String, in text: String, otherLines: [String] = []) -> String? {
        let paragraphs = split(text)
        let key = PlainWords.normalize(line)
        guard !key.isEmpty else { return nil }
        for paragraph in paragraphs {
            let flat = PlainWords.normalize(paragraph)
            guard let range = flat.range(of: key) else { continue }
            let rest = String(flat[range.lowerBound...])
            guard rest.count > key.count else { return nil }
            // Stop before any other item's words in the same paragraph.
            var end = rest.endIndex
            for other in otherLines.map(PlainWords.normalize) where !other.isEmpty && other != key {
                if let hit = rest.range(of: other), hit.lowerBound > rest.index(rest.startIndex, offsetBy: key.count - 1) {
                    end = min(end, hit.lowerBound)
                }
            }
            let result = String(rest[..<end]).trimmingCharacters(in: .whitespaces)
            return result.count > key.count ? restoreCase(result, from: paragraph) : nil
        }
        return nil
    }

    /// Paragraphs: split on blank lines and on lines that start a list item.
    static func split(_ text: String) -> [String] {
        var paragraphs: [String] = []
        var current: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let startsItem = line.range(of: #"^([•\-–*]|\d+[.)]|step \d+)"#, options: [.regularExpression, .caseInsensitive]) != nil
            if line.isEmpty || line.hasPrefix("--- Page") || startsItem {
                if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
                current = line.isEmpty || line.hasPrefix("--- Page") ? [] : [line]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
        return paragraphs
    }

    /// The matched words as the plan wrote them (original case and quotes).
    static func restoreCase(_ normalized: String, from paragraph: String) -> String {
        let words = paragraph.split(whereSeparator: \.isWhitespace).map(String.init)
        let target = normalized.split(separator: " ").count
        for start in words.indices {
            let candidate = words[start..<min(words.count, start + target)].joined(separator: " ")
            if PlainWords.normalize(candidate) == normalized { return candidate }
        }
        return normalized
    }
}

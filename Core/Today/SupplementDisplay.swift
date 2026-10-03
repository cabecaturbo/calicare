import Foundation

/// How a supplement reads on Plan: the stored words never change; only the
/// display does. "ADD Brand D Drops" shows as "Brand D Drops" with a New pill.
public struct SupplementDisplay: Equatable, Sendable {
    public let name: String
    /// The plan marked it "ADD": new to the routine.
    public let isNew: Bool
    /// One line: "2.5 ml (50 drops) · 2x per day".
    public let meta: String?
    /// The plan's directions, behind "How to give".
    public let howToGive: [String]

    public init(_ item: PlanItemInfo) {
        var name = item.text.trimmingCharacters(in: .whitespaces)
        isNew = name.hasPrefix("ADD ")
        if isNew { name = String(name.dropFirst(4)) }
        var note: String?
        for lead in ["Transition to ", "Switch to ", "Continue "] where name.hasPrefix(lead) {
            name = String(name.dropFirst(lead.count))
            if let range = name.range(of: " for ") {
                let rest = name[range.upperBound...]
                note = "For " + rest
                name = String(name[..<range.lowerBound])
            }
        }
        if name.hasSuffix(".") { name.removeLast() }
        self.name = name
        let parts = [item.dose, item.frequency].compactMap { $0 }
        meta = parts.isEmpty ? note.map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 } : parts.joined(separator: " · ")
        howToGive = [item.timing, item.duration].compactMap { $0 }
    }

    /// Lines that only mention a supplement: "Consider adding…", "…may be indicated".
    public static func isMention(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["consider", "may be indicated", "next steps", "might help", "could be helpful"].contains(where: lower.contains)
    }

    /// Lines that name a supplement to give without a dose ("Transition to X", "Continue X").
    static func isDirective(_ text: String) -> Bool {
        ["ADD ", "Transition to ", "Switch to ", "Continue "].contains(where: text.hasPrefix)
    }

    /// "Continue Vitamin C, Cod Liver Oil" → ["Vitamin C", "Cod Liver Oil"]. Only
    /// for "Continue" lists with no dose or schedule; one name returns one.
    public static func listedNames(_ text: String, dose: String?, frequency: String?) -> [String] {
        guard dose == nil, frequency == nil, text.hasPrefix("Continue ") else { return [] }
        let rest = text.dropFirst("Continue ".count).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return rest.replacingOccurrences(of: " and ", with: ", ")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

import Foundation

/// A card for a sitter or grandparent (Progress › Caregiver card): what the
/// parent wants them to know, in the parent's own words. Nothing is filled in
/// with advice; empty sections are left out.
public struct CaregiverCard: Codable, Equatable, Sendable {
    public struct Contact: Codable, Equatable, Sendable, Identifiable {
        public var id = UUID()
        public var name: String
        public var phone: String

        public init(name: String = "", phone: String = "") {
            self.name = name
            self.phone = phone
        }
    }

    public struct Section: Equatable, Sendable {
        public let title: String
        public let lines: [String]
    }

    public var childName: String
    /// Bedtime steps, one per line. Starts from Plan's evening routine.
    public var bedtime: String
    public var safeSnacks: String
    public var pleaseAvoid: String
    public var ifScratching: String
    public var contacts: [Contact]

    public init(childName: String, bedtime: String = "", safeSnacks: String = "", pleaseAvoid: String = "",
                ifScratching: String = "", contacts: [Contact] = []) {
        self.childName = childName
        self.bedtime = bedtime
        self.safeSnacks = safeSnacks
        self.pleaseAvoid = pleaseAvoid
        self.ifScratching = ifScratching
        self.contacts = contacts
    }

    /// A new card with bedtime taken from the evening routine steps.
    public static func starting(childName: String, eveningSteps: [String]) -> CaregiverCard {
        CaregiverCard(childName: childName, bedtime: eveningSteps.joined(separator: "\n"))
    }

    /// Only the sections with something in them, in order.
    public var sections: [Section] {
        let contactLines = contacts.compactMap { contact -> String? in
            let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let phone = contact.phone.trimmingCharacters(in: .whitespacesAndNewlines)
            switch (name.isEmpty, phone.isEmpty) {
            case (true, true): return nil
            case (false, false): return "\(name) · \(phone)"
            default: return name.isEmpty ? phone : name
            }
        }
        return [
            Section(title: "Bedtime routine", lines: Self.lines(bedtime)),
            Section(title: "Safe snacks", lines: Self.lines(safeSnacks)),
            Section(title: "Please avoid", lines: Self.lines(pleaseAvoid)),
            Section(title: "If \(childName) is scratching", lines: Self.lines(ifScratching)),
            Section(title: "Contacts", lines: contactLines),
        ].filter { !$0.lines.isEmpty }
    }

    public var isEmpty: Bool { sections.isEmpty }

    /// One item per line, trimmed, blank lines dropped.
    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

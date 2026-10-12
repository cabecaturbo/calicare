import Foundation

/// A card for a sitter or grandparent (Plan › Caregiver card): the active
/// plan's skin routine and schedule, plus what the parent wants them to know,
/// in the parent's own words. Nothing is filled in with advice; empty
/// sections are left out.
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
    /// Who it's for ("Grandma"). Optional; older saved cards don't have it.
    public var caregiver: String?
    /// Bedtime steps, one per line, used when the plan has no bedtime steps.
    public var bedtime: String
    public var safeSnacks: String
    public var pleaseAvoid: String
    public var ifScratching: String
    public var contacts: [Contact]

    public init(childName: String, caregiver: String? = nil, bedtime: String = "", safeSnacks: String = "",
                pleaseAvoid: String = "", ifScratching: String = "", contacts: [Contact] = []) {
        self.childName = childName
        self.caregiver = caregiver
        self.bedtime = bedtime
        self.safeSnacks = safeSnacks
        self.pleaseAvoid = pleaseAvoid
        self.ifScratching = ifScratching
        self.contacts = contacts
    }

    /// The parent's sections with something in them, in card order.
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
            Section(title: "If \(childName)’s scratching", lines: Self.lines(ifScratching)),
            Section(title: "Please avoid", lines: Self.lines(pleaseAvoid)),
            Section(title: "Safe snacks", lines: Self.lines(safeSnacks)),
            Section(title: "Contacts", lines: contactLines),
        ].filter { !$0.lines.isEmpty }
    }

    public var isEmpty: Bool { sections.isEmpty && Self.lines(bedtime).isEmpty }

    /// One item per line, trimmed, blank lines dropped.
    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// What the active plan says to do, for the caregiver card: the skin routine
/// in order, and what happens morning, afternoon and bedtime.
public struct CaregiverPlan: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let block: TodoBlock
        public let items: [String]
    }

    public let skinRoutine: [String]
    public let schedule: [Row]

    public init(skinRoutine: [String] = [], schedule: [Row] = []) {
        self.skinRoutine = skinRoutine
        self.schedule = schedule
    }

    /// From the plan's confirmed items and the active routine steps. Bedtime
    /// falls back to the parent's own bedtime lines when the plan has none.
    public init(items: [PlanItemInfo], steps: [RoutineStepInfo], bedtime: [String] = [], on date: Date = .now) {
        let skin = items.filter { $0.kind == .topicalStep && $0.isConfirmed }.sorted { $0.order < $1.order }
        skinRoutine = Self.unique(skin.map { $0.label ?? StepLabeler.clean($0.text) })
        let active = steps.filter(\.isActive).sorted { $0.order < $1.order }
        let giving = items.filter { $0.kind == .supplement && $0.isGiving == true }
        schedule = TodoBlock.allCases.compactMap { block in
            let time: RoutineTime? = block == .morning ? .morning : block == .bedtime ? .evening : nil
            var lines = active.filter { $0.time == time }.map(\.displayName)
            if block == .bedtime, lines.isEmpty { lines = bedtime }
            lines += giving.filter { ($0.givingTimes ?? []).contains(block) }.map { item in
                let name = SupplementDisplay(item).name
                return item.dose(on: date).map { "\(name), \($0)" } ?? name
            }
            let unique = Self.unique(lines)
            return unique.isEmpty ? nil : Row(block: block, items: unique)
        }
    }

    static func unique(_ lines: [String]) -> [String] {
        var seen: Set<String> = []
        return lines.filter { seen.insert($0).inserted }
    }
}

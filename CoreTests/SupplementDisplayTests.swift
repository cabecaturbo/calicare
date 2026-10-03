import Core
import Foundation
import Testing

/// Supplements read cleanly without changing what's stored, and the avoid
/// list shows one thing per line.
struct SupplementDisplayTests {
    private func item(_ text: String, dose: String? = nil, frequency: String? = nil, timing: String? = nil,
                      duration: String? = nil, order: Int = 0, parent: UUID? = nil, kind: PlanItemKind = .supplement) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: UUID(), kind: kind, text: text, dose: dose, frequency: frequency, timing: timing,
                     duration: duration, sourcePage: 1, sourceLine: text, isConfirmed: true, order: order, parentItemID: parent)
    }

    @Test func addBecomesANewPill() {
        let ion = item("ADD ION Gut Support", dose: "1 teaspoon (5ml)", frequency: "2x per day",
                       timing: "Start low and increase slowly.", duration: "Can take long-term.")
        let display = SupplementDisplay(ion)
        #expect(display.name == "ION Gut Support")
        #expect(display.isNew)
        #expect(display.meta == "1 teaspoon (5ml) · 2x per day")
        #expect(display.howToGive == ["Start low and increase slowly.", "Can take long-term."])
        #expect(ion.text == "ADD ION Gut Support")

        let switchTo = SupplementDisplay(item("Transition to Brand J Chewables for a multi-vitamin"))
        #expect(switchTo.name == "Brand J Chewables")
        #expect(switchTo.meta == "For a multi-vitamin")
        #expect(!switchTo.isNew)
    }

    @Test func listsSplitAndMentionsStepAside() {
        #expect(SupplementDisplay.listedNames("Continue Vitamin C, Cod Liver Oil", dose: nil, frequency: nil) == ["Vitamin C", "Cod Liver Oil"])
        #expect(SupplementDisplay.listedNames("Continue Vitamin C", dose: nil, frequency: nil) == ["Vitamin C"])
        #expect(SupplementDisplay.listedNames("Continue Vitamin C, Fish Oil", dose: "1 tsp", frequency: nil).isEmpty)

        let list = item("Continue Vitamin C, Cod Liver Oil", order: 0)
        let a = item("Vitamin C", order: 0, parent: list.id)
        let b = item("Cod Liver Oil", order: 0, parent: list.id)
        let drops = item("ADD Herbal Drops", dose: "8 drops", frequency: "3x daily", order: 1)
        let maybe = item("SunButyrate is helpful for gut lining support and may be indicated.", order: 2)
        let consider = item("Next Steps: Consider adding MegaIGG 2000 to further support immune function.", order: 3)
        let switchTo = item("Transition to Brand J Chewables for a multi-vitamin.", order: 4)
        let rule = item("Add one at a time, 3-5 days apart", order: 5)
        let plan = SupplementPlan(items: [list, a, b, drops, maybe, consider, switchTo, rule], logs: [], now: .now)
        #expect(Set(plan.rows.map(\.item.text)) == ["Vitamin C", "Cod Liver Oil", "ADD Herbal Drops", switchTo.text])
        #expect(plan.mentioned.map(\.text) == [maybe.text, consider.text])
        #expect(plan.rules == [rule.text])
        #expect(plan.rows.first { $0.item.id == drops.id }?.perDay == 3)
    }

    @Test func avoidListOnePerLine() {
        let items = [
            item("Avoid confirmed allergens and triggers", kind: .foodRule),
            item("Avoid inflammatory foods including dairy, gluten, eggs, soy and nuts", kind: .foodRule),
            item("Avoid artificial sugar and processed foods as much as possible. Buy organic when able", kind: .foodRule),
        ]
        let lines = PlanFoods.avoidedLines(in: items)
        #expect(lines.map(\.name) == ["Confirmed allergens and triggers", "Dairy", "Gluten", "Eggs", "Soy", "Nuts",
                                      "Artificial sugar", "Processed foods"])
        #expect(lines.first?.isFood == false)
        #expect(lines.last?.qualifier == "as much as possible · Buy organic when able")
        #expect(lines.first { $0.name == "Dairy" }?.qualifier == nil)
        #expect(!PlanFoods.avoided(in: items).contains("Confirmed allergens and triggers"))
    }
}

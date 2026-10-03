import Core
import Foundation
import Testing

/// Food changes in "Worse since when?", and what may be less covered.
struct FoodTimelineTests {
    private let child = UUID()

    @Test func foodChangesJoinTheTimeline() {
        let eggs = FoodInfo(id: UUID(), childID: child, name: "Eggs", family: "Poultry", status: .paused,
                            statusChangedAt: TestTime.date(20, 9), decidedBy: .plan, note: nil)
        let oats = FoodInfo(id: UUID(), childID: child, name: "Oats", family: nil, status: .safe,
                            statusChangedAt: TestTime.date(21, 9), decidedBy: .parent, note: nil)
        let logs = [
            LogEntry(childID: child, type: .foodTrial, value: .trial(.started), note: "3 days", timestamp: TestTime.date(22, 9), routineStepID: eggs.id),
            LogEntry(childID: child, type: .foodTrial, value: .trial(.given), timestamp: TestTime.date(22, 12), routineStepID: eggs.id),
            LogEntry(childID: child, type: .foodTrial, value: .trial(.worthWatching), timestamp: TestTime.date(23, 7), routineStepID: eggs.id),
        ]
        let changes = CareChanges.list(plans: [], items: [:], logs: logs, foods: [eggs, oats])
        #expect(changes.map(\.text) == ["Eggs: worth watching", "Started a trial: Eggs", "Paused Eggs"])
        #expect(changes.allSatisfy { $0.isFood })
    }

    @Test func nutrientsWorthAskingAbout() {
        #expect(NutrientCoverage.lessCovered(paused: ["Dairy", "Eggs"]) == ["calcium", "vitamin D", "protein", "choline"])
        #expect(NutrientCoverage.sentence(paused: ["Dairy", "Eggs"])
            == "With dairy and eggs paused, calcium, vitamin D, protein, and choline may be less covered. Worth asking your provider or a dietitian.")
        #expect(NutrientCoverage.sentence(paused: ["Eggplant"]) == nil)
        // Never names a supplement or a food to add.
        let text = NutrientCoverage.sentence(paused: ["Dairy", "Fish", "Wheat", "Beef"]) ?? ""
        for word in ["supplement", "take", "add", "try", "cause", "trigger", "likely"] {
            #expect(!text.lowercased().contains(word), "\(word)")
        }
    }
}

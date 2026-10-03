import Core
import Foundation
import Testing

/// Rotation by family and the weekly plant counter, from the plan's words.
struct FoodRotationTests {
    private let child = UUID()

    private func rule(_ text: String) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: UUID(), kind: .foodRule, text: text, dose: nil, frequency: nil, timing: nil,
                     duration: nil, sourcePage: 2, sourceLine: nil, isConfirmed: true, order: 0)
    }

    private func food(_ name: String, _ status: FoodStatus = .safe) -> FoodInfo {
        FoodInfo(id: UUID(), childID: child, name: name, family: FoodFamilies.family(for: name), status: status,
                 statusChangedAt: TestTime.date(20, 9), decidedBy: .parent, note: nil)
    }

    @Test func readsThePlansRotationAndGoal() {
        let items = [rule("4-day rotation by food family, 40–50 plants/week")]
        #expect(FoodRotation.days(in: items) == 4)
        #expect(FoodRotation.plantGoal(in: items) == 40...50)
        #expect(FoodRotation.plantGoal(in: [rule("Aim for 30 plants a week")]) == 30...30)
        #expect(FoodRotation.days(in: [rule("Avoid: dairy")]) == nil)
    }

    @Test func arrangesOnlySafeFoodsByFamily() {
        let foods = [food("Oats"), food("Rice"), food("Apple"), food("Pear"), food("Chicken"), food("Eggs", .paused), food("Kale")]
        let plan = FoodRotation.plan(foods: foods, days: 2)
        let all = plan.flatMap { $0 }
        #expect(!all.flatMap(\.foods).contains("Eggs"))
        #expect(all.first { $0.family == "Grasses (grains)" }?.foods == ["Oats", "Rice"])
        #expect(Set(plan[0].map(\.family)).isDisjoint(with: plan[1].map(\.family)))
        #expect(abs(plan[0].count - plan[1].count) <= 1)
    }

    @Test func todaysDayAndPlantsThisWeek() {
        #expect(FoodRotation.today(start: TestTime.date(20, 9), days: 4, now: TestTime.date(26, 8), calendar: TestTime.calendar) == 2)
        let foods = [food("Oats"), food("Apple"), food("Chicken")]
        let meals = [
            LogEntry(childID: child, type: .meal, note: "Oats, Apple, Chicken", timestamp: TestTime.date(28, 8)),
            LogEntry(childID: child, type: .meal, note: "Oats, Kale", timestamp: TestTime.date(29, 12)),
            LogEntry(childID: child, type: .meal, note: "Pear", timestamp: TestTime.date(26, 12)), // last week
        ]
        #expect(FoodRotation.plantsThisWeek(meals: meals, foods: foods, now: TestTime.date(29, 20), calendar: TestTime.calendar)
            == ["oats", "apple", "kale"])
    }
}

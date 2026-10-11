import Core
import Foundation
import Testing
import UIKit

/// The caregiver card: the plan's routine and schedule, then the parent's
/// own words, with empty sections hidden. Set DESIGN_OUT to save the render.
struct CaregiverCardTests {
    @Test func linesAreTrimmedAndBlankLinesDropped() {
        var card = CaregiverCard(childName: "Cal")
        card.safeSnacks = "  Apple slices \n\n Rice cakes\n"
        card.ifScratching = "Cool cloth, then call us"
        card.contacts = [.init(name: "Mom", phone: "555 0100"), .init(name: "", phone: ""), .init(name: "Dr. Lee's office", phone: "")]
        #expect(card.sections.map(\.title) == ["If Cal’s scratching", "Safe snacks", "Contacts"])
        #expect(card.sections[1].lines == ["Apple slices", "Rice cakes"])
        #expect(card.sections[2].lines == ["Mom · 555 0100", "Dr. Lee's office"])
    }

    @Test func anEmptyCardIsEmpty() {
        #expect(CaregiverCard(childName: "Cal").isEmpty)
        #expect(!CaregiverCard(childName: "Cal", bedtime: "Bath").isEmpty)
    }

    @Test func olderSavedCardsStillLoad() throws {
        let saved = #"{"childName":"Cal","bedtime":"Bath","safeSnacks":"","pleaseAvoid":"","ifScratching":"","contacts":[]}"#
        let card = try JSONDecoder().decode(CaregiverCard.self, from: Data(saved.utf8))
        #expect(card.caregiver == nil)
        #expect(card.bedtime == "Bath")
    }

    static let planID = UUID()

    static func item(_ kind: PlanItemKind, _ text: String, order: Int, dose: String? = nil, giving: Bool? = nil,
                     times: [TodoBlock]? = nil, label: String? = nil) -> PlanItemInfo {
        PlanItemInfo(id: UUID(), planID: planID, kind: kind, text: text, dose: dose, frequency: nil, timing: nil, duration: nil,
                     sourcePage: nil, sourceLine: nil, isConfirmed: true, order: order, label: label, isGiving: giving,
                     givingTimes: times)
    }

    static var plan: CaregiverPlan {
        let child = UUID()
        let items = [
            item(.topicalStep, "Step 1: Calendula cream, if tolerated.", order: 1, label: "Put on calendula cream"),
            item(.topicalStep, "Step 2: Plain aloe gel.", order: 2, label: "Put on plain aloe gel"),
            item(.supplement, "Vitamin D3 drops", order: 3, dose: "1 drop", giving: true, times: [.morning]),
            item(.supplement, "Probiotic powder", order: 4, dose: "1/4 tsp", giving: true, times: [.afternoon, .bedtime]),
            item(.supplement, "Zinc chewable", order: 5, giving: false, times: [.morning]),
        ]
        let steps = [
            RoutineStepInfo(id: UUID(), childID: child, name: "Wash face", time: .morning, order: 0, isActive: true),
            RoutineStepInfo(id: UUID(), childID: child, name: "Bath", time: .evening, order: 1, isActive: true),
            RoutineStepInfo(id: UUID(), childID: child, name: "Pajamas", time: .evening, order: 2, isActive: true),
        ]
        return CaregiverPlan(items: items, steps: steps)
    }

    @Test func thePlanGivesTheRoutineAndTheSchedule() {
        let plan = Self.plan
        #expect(plan.skinRoutine == ["Put on calendula cream", "Put on plain aloe gel"])
        #expect(plan.schedule.map(\.block) == [.morning, .afternoon, .bedtime])
        #expect(plan.schedule[0].items == ["Wash face", "Vitamin D3 drops, 1 drop"])
        #expect(plan.schedule[1].items == ["Probiotic powder, 1/4 tsp"])
        #expect(plan.schedule[2].items == ["Bath", "Pajamas", "Probiotic powder, 1/4 tsp"])
    }

    @MainActor @Test func rendersAPhoneSizedPictureAndAPDF() throws {
        var card = CaregiverCard(childName: "Cal", caregiver: "Grandma")
        card.ifScratching = "Cool, damp cloth on the spot\nTrim nails if they're long"
        card.pleaseAvoid = "Dairy and eggs\nWool blankets"
        card.contacts = [.init(name: "Matt", phone: "555 0100")]
        let view = CaregiverCardView(card: card, plan: Self.plan, parentName: "Matt",
                                     date: TestTime.date(2026, 10, 11, 12))
        let image = try #require(CaregiverCardRenderer.image(for: view))
        #expect(image.size == CaregiverCardView.size)
        #expect(image.scale == 3)
        #expect(CaregiverCardRenderer.pdfData(for: view).starts(with: Data("%PDF".utf8)))
        if let folder = ProcessInfo.processInfo.environment["DESIGN_OUT"] {
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try? image.pngData()?.write(to: URL(fileURLWithPath: folder).appendingPathComponent("caregiver-card.png"))
        }
    }
}

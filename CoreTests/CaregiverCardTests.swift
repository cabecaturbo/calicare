import Core
import Foundation
import Testing

/// The caregiver card: the parent's words only, empty sections hidden.
struct CaregiverCardTests {
    @Test func startsFromTheEveningRoutineAndHidesEmptySections() {
        let card = CaregiverCard.starting(childName: "Cal", eveningSteps: ["Bath", "Moisturizer", "Pajamas"])
        #expect(card.sections.map(\.title) == ["Bedtime routine"])
        #expect(card.sections.first?.lines == ["Bath", "Moisturizer", "Pajamas"])
    }

    @Test func linesAreTrimmedAndBlankLinesDropped() {
        var card = CaregiverCard(childName: "Cal")
        card.safeSnacks = "  Apple slices \n\n Rice cakes\n"
        card.ifScratching = "Cool cloth, then call us"
        card.contacts = [.init(name: "Mom", phone: "555 0100"), .init(name: "", phone: ""), .init(name: "Dr. Lee's office", phone: "")]
        #expect(card.sections.map(\.title) == ["Safe snacks", "If Cal is scratching", "Contacts"])
        #expect(card.sections[0].lines == ["Apple slices", "Rice cakes"])
        #expect(card.sections[2].lines == ["Mom · 555 0100", "Dr. Lee's office"])
    }

    @Test func anEmptyCardIsEmpty() {
        #expect(CaregiverCard(childName: "Cal").isEmpty)
    }

    @MainActor @Test func rendersAPictureAndAPDF() throws {
        let card = CaregiverCard(childName: "Cal", bedtime: "Bath\nPajamas")
        let image = try #require(CaregiverCardRenderer.image(for: card))
        #expect(image.size.width * image.scale == 1800)
        #expect(CaregiverCardRenderer.pdfData(for: card).starts(with: Data("%PDF".utf8)))
    }
}

import Core
import SwiftUI

/// Progress › Caregiver card: the parent writes what a sitter needs to know,
/// sees the card, and shares it as a picture or a PDF. Saved per child on
/// this phone.
struct CaregiverCardSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let child: ChildInfo
    @State private var card: CaregiverCard
    @State private var files: (image: URL, pdf: URL)?

    init(child: ChildInfo, eveningSteps: [String]) {
        self.child = child
        _card = State(initialValue: CaregiverCardStore.load(child: child) ?? .starting(childName: child.name, eveningSteps: eveningSteps))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    Text("Only what you write here goes on the card. Empty sections are left off.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)

                    field("Bedtime routine", hint: "One step per line", text: $card.bedtime)
                    field("Safe snacks", hint: "One per line", text: $card.safeSnacks)
                    field("Please avoid", hint: "One per line", text: $card.pleaseAvoid)
                    field("If \(child.name) is scratching", hint: "What you'd like them to do", text: $card.ifScratching)
                    contacts

                    if !card.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.x3) {
                            Text("The card")
                                .textStyle(.section)
                                .foregroundStyle(palette.ink)
                            preview
                        }
                    }
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x5)
                .padding(.bottom, 96) // room above the Share buttons
            }
            .paperBackground()
            .navigationTitle("Caregiver card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if let files, !card.isEmpty {
                        ShareLink(item: files.image) { Text("Share picture") }
                        Spacer()
                        ShareLink(item: files.pdf) { Text("Share PDF") }
                    }
                }
            }
        }
        .tint(palette.indigo)
        .task(id: card) {
            CaregiverCardStore.save(card, child: child)
            try? await Task.sleep(for: .milliseconds(400))
            files = try? CaregiverCardRenderer.files(for: card)
        }
    }

    private func field(_ title: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text(title)
                .textStyle(.section)
                .foregroundStyle(palette.ink)
            TextField(hint, text: text, axis: .vertical)
                .textStyle(.body)
                .lineLimit(2...8)
                .padding(Spacing.x3)
                .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.control))
        }
    }

    private var contacts: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Contacts")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
            ForEach($card.contacts) { $contact in
                HStack(spacing: Spacing.x2) {
                    TextField("Name", text: $contact.name)
                    TextField("Phone", text: $contact.phone)
                        .keyboardType(.phonePad)
                }
                .textStyle(.body)
                .padding(Spacing.x3)
                .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.control))
            }
            Button("Add a contact") { card.contacts.append(.init()) }
                .buttonStyle(.textLink)
        }
    }

    /// The card scaled to the screen, with a hairline edge like a printed page.
    private var preview: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / CaregiverCardView.size.width
            CaregiverCardView(card: card)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: proxy.size.width, height: CaregiverCardView.size.height * scale, alignment: .topLeading)
                .overlay(Rectangle().strokeBorder(palette.hairline, lineWidth: Rule.width))
        }
        .aspectRatio(CaregiverCardView.size.width / CaregiverCardView.size.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Caregiver card for \(child.name): " + card.sections.map { "\($0.title): \($0.lines.joined(separator: ", "))" }.joined(separator: ". "))
    }
}

/// Each child's caregiver card, on this phone only.
enum CaregiverCardStore {
    private static func key(_ child: ChildInfo) -> String { "caregiverCard.\(child.id.uuidString)" }

    static func load(child: ChildInfo) -> CaregiverCard? {
        guard let data = UserDefaults.standard.data(forKey: key(child)),
              var card = try? JSONDecoder().decode(CaregiverCard.self, from: data)
        else { return nil }
        card.childName = child.name
        return card
    }

    static func save(_ card: CaregiverCard, child: ChildInfo) {
        guard let data = try? JSONEncoder().encode(card) else { return }
        UserDefaults.standard.set(data, forKey: key(child))
    }
}

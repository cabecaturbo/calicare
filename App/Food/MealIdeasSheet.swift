import Core
import Supabase
import SwiftUI

/// Food list › "What can I make": tap what's in the fridge (from the safe and
/// testing list), get a few simple meals. Paused foods are always sent as
/// "avoid", and the server drops any idea that mentions one. Sign-in once.
struct MealIdeasSheet: View {
    struct Idea: Decodable, Identifiable, Hashable {
        let title: String
        let ingredients: [String]
        let steps: [String]
        var id: String { title }
    }

    private struct Response: Decodable {
        let ideas: [Idea]
        let note: String
    }

    private struct Request: Encodable {
        let fridge: [String]
        let safe: [String]
        let avoid: [String]
    }

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    @Environment(AccountController.self) private var account
    @State private var fridge: Set<String> = []
    @State private var ideas: [Idea] = []
    @State private var note: String?
    @State private var working = false
    @State private var problem: String?
    @State private var signingIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    if isSignedIn {
                        VStack(alignment: .leading, spacing: Spacing.x4) {
                            Text("What's in the fridge?").textStyle(.section).foregroundStyle(palette.ink)
                            FoodChips(items: model.foods.filter { $0.status != .paused }.map(\.name), picked: $fridge)
                            Button(working ? "Thinking…" : "Get ideas") { Task { await getIdeas() } }
                                .buttonStyle(.primary)
                                .disabled(fridge.isEmpty || working)
                        }
                    } else {
                        Text("Sign in once to get meal ideas.").textStyle(.body).foregroundStyle(palette.ink)
                        Button("Sign in with Apple") { signingIn = true }.buttonStyle(.primary)
                    }
                    if let problem {
                        Text(problem).textStyle(.body).foregroundStyle(palette.ink)
                    }
                    ForEach(ideas) { idea in
                        VStack(alignment: .leading, spacing: Spacing.x1) {
                            Text(idea.title).textStyle(.title).foregroundStyle(palette.ink)
                            Text(idea.ingredients.joined(separator: " · ")).textStyle(.meta).foregroundStyle(palette.graphite)
                            ForEach(Array(idea.steps.enumerated()), id: \.offset) { index, step in
                                Text("\(index + 1). \(step)").textStyle(.body).foregroundStyle(palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(Spacing.x4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.card))
                    }
                    if let note, !ideas.isEmpty {
                        Text("\(note) Paused foods are never used. Not medical advice.")
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.x5)
            }
            .paperBackground()
            .navigationTitle("What can I make")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(palette.indigo)
        .sheet(isPresented: $signingIn) {
            AccountSheet().environment(account).nightAwarePalette()
        }
    }

    private var isSignedIn: Bool {
        if case .signedIn = account.state { return true }
        return false
    }

    private func getIdeas() async {
        guard let client = Backend.client else { return }
        working = true
        defer { working = false }
        let safe = model.foods.filter { $0.status == .safe }.map(\.name)
        let avoid = model.foods.filter { $0.status == .paused }.map(\.name)
            + PlanFoods.avoided(in: Array(model.planItems.values))
        do {
            let response: Response = try await client.functions.invoke(
                "meal-ideas",
                options: FunctionInvokeOptions(method: .post, body: Request(fridge: fridge.sorted(), safe: safe, avoid: avoid))
            )
            ideas = response.ideas
            note = response.note
            problem = ideas.isEmpty ? "No ideas that fit just these foods. Try picking a few more." : nil
        } catch let FunctionsError.httpError(code, _) where code == 429 {
            problem = "That's a lot of ideas for one day. Please try again tomorrow."
        } catch {
            problem = "Couldn't get ideas just now. Check your connection and try again."
        }
    }
}

/// Tappable food names, wrapping onto new lines.
struct FoodChips: View {
    @Environment(\.palette) private var palette
    let items: [String]
    @Binding var picked: Set<String>

    var body: some View {
        if items.isEmpty {
            Text("Add safe foods to the food list first.").textStyle(.body).foregroundStyle(palette.graphite)
        }
        ChipFlow(spacing: Spacing.x2) {
            ForEach(items, id: \.self) { item in
                let on = picked.contains(item)
                Button {
                    if on { picked.remove(item) } else { picked.insert(item) }
                } label: {
                    Text(item)
                        .textStyle(.body)
                        .foregroundStyle(on ? palette.paper : palette.ink)
                        .padding(.horizontal, Spacing.x4)
                        .frame(minHeight: Size.touchTarget)
                        .background(on ? palette.indigo : palette.paper, in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? palette.indigo : palette.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Lays children out in rows, wrapping when a row is full.
struct ChipFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

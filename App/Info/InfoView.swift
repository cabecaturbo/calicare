import Core
import SwiftUI

/// Info: "What does the plan say?" One row per part of the plan; each opens
/// its own screen. No paragraphs or links here.
struct InfoView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "Info")
                    VStack(spacing: 0) {
                        InfoRow(title: "Care plan", detail: planDetail) { CarePlanScreen() }
                        InfoRow(title: "Supplements", detail: supplementsDetail) { SupplementsScreen() }
                        InfoRow(title: "Patch tests", detail: nil) { PatchTestsScreen() }
                        InfoRow(title: "Visits and journal", detail: visitsDetail) { VisitsScreen() }
                        InfoRow(title: "Food", detail: foodDetail) { FoodListView() }
                        InfoRow(title: "Products", detail: productsDetail) { ProductListView() }
                    }
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x5)
                }
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task { await model.load() }
        }
    }

    private var planDetail: String? {
        guard let plan = model.activePlan else { return "Add your plan" }
        return plan.provider.isEmpty ? "Started" : "From \(plan.provider)"
    }

    private var supplementsDetail: String? {
        let rows = model.supplementPlan.rows
        guard !rows.isEmpty else { return nil }
        let giving = rows.filter { $0.item.isGiving == true }.count
        let notYet = rows.count - giving
        return notYet > 0 ? "\(giving) giving · \(notYet) not yet" : "\(giving) giving"
    }

    private var visitsDetail: String? {
        model.providerTracker.lastVisit.map { "Last visit \($0.date.formatted(.dateTime.month(.abbreviated).day()))" }
    }

    private var foodDetail: String? {
        guard !model.foods.isEmpty else { return nil }
        let safe = model.foods.filter { $0.status == .safe }.count
        let paused = model.foods.filter { $0.status == .paused }.count
        return paused > 0 ? "\(safe) safe · \(paused) paused" : "\(safe) safe"
    }

    private var productsDetail: String? {
        let inUse = model.products.filter(\.inUse).count
        return inUse > 0 ? "\(inUse) in use" : nil
    }
}

/// One Info row: a name, a short detail, and a chevron to its screen.
private struct InfoRow<Destination: View>: View {
    @Environment(\.palette) private var palette
    let title: String
    let detail: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            AdaptiveStack {
                Text(title).textStyle(.body).foregroundStyle(palette.ink)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail).textStyle(.meta).foregroundStyle(palette.graphite)
                }
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.graphite)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
    }
}

/// A pushed Info screen's frame: scrolls, margins, solid bar, inline title.
struct InfoScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x7) {
                content()
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.x5)
            .padding(.bottom, BottomBar.clearance)
        }
        .paperBackground()
        .solidNavigationBar(.paper)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Info › Care plan: "What does the plan say?" The plan itself, and its baths.
struct CarePlanScreen: View {
    @Environment(TodayModel.self) private var model

    var body: some View {
        InfoScreen(title: "Care plan") {
            CarePlanSection()
            let baths = model.bathWeek
            if !baths.rows.isEmpty || !baths.notes.isEmpty {
                BathsSection(week: baths)
            }
        }
    }
}

/// Info › Visits and journal: when to see the provider, and the journal for them.
struct VisitsScreen: View {
    @Environment(TodayModel.self) private var model

    var body: some View {
        InfoScreen(title: "Visits and journal") {
            ProviderSection(tracker: model.providerTracker)
        }
    }
}

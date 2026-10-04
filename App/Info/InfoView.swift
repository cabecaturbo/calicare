import Core
import SwiftUI

/// Care plan: "What did the doctor tell us?" One big statement (whose plan,
/// from when), then one row per part of the plan; each opens its own screen.
struct InfoView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "Care plan", why: "What \(model.child?.name ?? "your child")’s doctor told you, in one place.")
                    BigStatement(text: statement.text, line: statement.line)
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x6)
                    VStack(spacing: 0) {
                        InfoRow(title: "The full plan", detail: planDetail) { CarePlanScreen() }
                        InfoRow(title: "Supplements", detail: supplementsDetail) { SupplementsScreen() }
                        InfoRow(title: "Patch tests", detail: nil) { PatchTestsScreen() }
                        InfoRow(title: "Visits and notes", detail: visitsDetail) { VisitsScreen() }
                        InfoRow(title: "Food", detail: foodDetail) { FoodListView() }
                        InfoRow(title: "Products", detail: productsDetail) { ProductListView() }
                    }
                    .overlay(alignment: .top) { palette.hairline.frame(height: Rule.width) }
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x5)
                }
                .padding(.bottom, Spacing.x5)
            }
            .paperBackground()
            .statusBarBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task { await model.load() }
        }
    }

    /// "Dr. Lee's plan, from Sep 12." or, before a plan, how to add one.
    private var statement: (text: String, line: String?) {
        guard let plan = model.activePlan else {
            return ("No care plan yet.", "Add the plan from \(model.child?.name ?? "your child")’s doctor.")
        }
        let whose = plan.provider.isEmpty ? "Your doctor’s plan" : "\(plan.provider)’s plan"
        let date = (plan.planDate ?? plan.startedAt).map { ", from \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? ""
        return ("\(whose)\(date).", "Tap a part to read it.")
    }

    private var planDetail: String? {
        model.activePlan == nil ? "Add your plan" : nil
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
            .padding(.bottom, Spacing.x5)
        }
        .paperBackground()
        .solidNavigationBar(.paper)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Care plan › The full plan: what the plan says, and its baths.
struct CarePlanScreen: View {
    @Environment(TodayModel.self) private var model

    var body: some View {
        InfoScreen(title: "The full plan") {
            CarePlanSection()
            let baths = model.bathWeek
            if !baths.rows.isEmpty || !baths.notes.isEmpty {
                BathsSection(week: baths)
            }
        }
    }
}

/// Care plan › Visits and notes: when to see the doctor, and notes for them.
struct VisitsScreen: View {
    @Environment(TodayModel.self) private var model

    var body: some View {
        InfoScreen(title: "Visits and notes") {
            ProviderSection(tracker: model.providerTracker)
        }
    }
}

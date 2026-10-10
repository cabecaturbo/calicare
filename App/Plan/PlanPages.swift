import Core
import SwiftUI

/// One Plan row: a name, a short detail, and a chevron to its screen.
struct PlanRow<Destination: View>: View {
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
            .frame(minHeight: 50)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
    }
}

/// A pushed Plan screen's frame: scrolls, margins, solid bar, inline title.
struct PlanPage<Content: View>: View {
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

/// Plan › Baths: what the plan says about baths, and this week's.
struct BathsScreen: View {
    @Environment(TodayModel.self) private var model

    var body: some View {
        PlanPage(title: "Baths") {
            BathsSection(week: model.bathWeek)
        }
    }
}

/// Plan › Visits and journal: when to see the provider, and the journal for them.
struct VisitsScreen: View {
    @Environment(TodayModel.self) private var model

    var body: some View {
        PlanPage(title: "Visits and journal") {
            ProviderSection(tracker: model.providerTracker)
        }
    }
}

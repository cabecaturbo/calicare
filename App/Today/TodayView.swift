import Core
import SwiftUI

/// Placeholder Today screen. Real logging and summaries come in later prompts.
struct TodayView: View {
    @Environment(\.palette) private var palette
    @State private var showingSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Last night")
                        .font(Typography.title3)
                        .foregroundStyle(palette.ink)
                    Text("Nothing logged yet. Whenever you're ready.")
                        .font(Typography.body)
                        .foregroundStyle(palette.muted)
                }
                .cardStyle()

                Text("One-tap logging buttons will live here.")
                    .font(Typography.callout)
                    .foregroundStyle(palette.sageDark)
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.sand, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

                severityLegend
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xl)
        }
        .background(palette.background.ignoresSafeArea())
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
                Text("Today")
                    .font(Typography.largeTitle)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(palette.sageDark)
                    .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
            }
            .accessibilityLabel("Settings")
        }
    }

    private var severityLegend: some View {
        HStack(spacing: Spacing.s) {
            legendPill("Calm", color: palette.severityLow, text: palette.sageDark)
            legendPill("Medium", color: palette.severityMedium, text: palette.ink)
            legendPill("Itchy", color: palette.severityHigh, text: palette.onAccent)
        }
        .accessibilityElement(children: .combine)
    }

    private func legendPill(_ title: String, color: Color, text: Color) -> some View {
        Text(title)
            .font(Typography.caption)
            .foregroundStyle(text)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: TouchTarget.minimum)
            .background(color, in: Capsule())
    }
}

#Preview("Day") {
    TodayView()
        .environment(\.palette, .day)
        .onAppear { FontRegistry.registerAll() }
}

#Preview("Night") {
    TodayView()
        .environment(\.palette, .night)
        .onAppear { FontRegistry.registerAll() }
}

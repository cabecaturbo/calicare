import Core
import SwiftUI

/// Pick a child and a week, preview the card, and share it.
struct ReportsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var children: [ChildInfo] = []
    @State private var child: ChildInfo?
    @State private var weekEnding = CareDay.containing(.now)
    @State private var report: WeeklyReport?
    @State private var file: URL?
    @State private var problem: String?

    private var isThisWeek: Bool { weekEnding >= CareDay.containing(.now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LedgerSection {
                        if children.count > 1 { childRow }
                        weekRow
                    }

                    preview
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.ledeToSection)

                    VStack(alignment: .leading, spacing: Spacing.x2) {
                        if let file {
                            ShareLink(item: file) { Text("Share") }
                                .buttonStyle(.primary)
                        }
                        Text("Shares as a picture. Always light, even at night, so it reads well anywhere.")
                            .textStyle(.meta)
                            .foregroundStyle(palette.graphite)
                        if let problem {
                            Text(problem)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.section)
                }
                .padding(.vertical, Spacing.x4)
            }
            .paperBackground()
            .navigationTitle("Weekly card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(palette.indigo)
        .task { await loadChildren() }
        .task(id: "\(child?.id.uuidString ?? "")-\(weekEnding)") { await build() }
    }

    private var childRow: some View {
        LedgerRow {
            Text("Child")
                .textStyle(.control)
                .foregroundStyle(palette.ink)
        } trailing: {
            Menu {
                ForEach(children) { option in
                    Button(option.name) { child = option }
                }
            } label: {
                Text(child?.name ?? "")
                    .textStyle(.control)
                    .foregroundStyle(palette.indigo)
            }
            .accessibilityLabel("Child: \(child?.name ?? "")")
        }
    }

    private var weekRow: some View {
        LedgerRow {
            Text(report?.dateRange() ?? "")
                .textStyle(.control)
                .foregroundStyle(palette.ink)
                .accessibilityLabel("Week of \(report?.dateRange() ?? "")")
        } trailing: {
            HStack(spacing: Spacing.x4) {
                Button("Earlier") { weekEnding = weekEnding.adding(days: -7) }
                    .buttonStyle(.textLink)
                    .accessibilityLabel("Earlier week")
                Button("Later") { weekEnding = weekEnding.adding(days: 7) }
                    .buttonStyle(.textLink)
                    .disabled(isThisWeek)
                    .opacity(isThisWeek ? 0.4 : 1)
                    .accessibilityLabel("Later week")
            }
        }
    }

    /// The card, scaled to the screen, with a hairline edge like a printed page.
    private var preview: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / WeeklyCardView.size.width
            Group {
                if let report {
                    WeeklyCardView(report: report)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: proxy.size.width, height: WeeklyCardView.size.height * scale, alignment: .topLeading)
                }
            }
            .overlay(Rectangle().strokeBorder(palette.hairline, lineWidth: Rule.width))
        }
        .aspectRatio(WeeklyCardView.size.width / WeeklyCardView.size.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let report else { return "Weekly card" }
        var parts = ["Weekly card for \(report.child.name), \(report.dateRange()).", "\(report.headline.text)."]
        if report.headline != .notEnoughLogs {
            parts.append("\(report.goodNights) good nights of 7. \(report.itchyWakeUps) itchy wake-ups.")
        }
        if let line = report.worthWatching { parts.append(line) }
        return parts.joined(separator: " ")
    }

    private func loadChildren() async {
        guard let store = try? ChildStore(modelContainer: CaliCareModelContainer.shared()) else { return }
        children = (try? await store.activeChildren()) ?? []
        if child == nil { child = try? await store.currentChild() }
    }

    private func build() async {
        guard let child, let container = try? CaliCareModelContainer.shared() else { return }
        do {
            let report = try await WeeklyReport.load(child: child, weekEnding: weekEnding, container: container)
            self.report = report
            file = try WeeklyCardRenderer.file(for: report)
            problem = nil
        } catch {
            problem = "Couldn't make the card just now. Try again in a moment."
        }
    }
}

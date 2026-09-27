import Core
import SwiftUI

/// Progress: the weekly card (pick a week, preview, share) and the doctor report.
/// Contents are the old Weekly card screen until U5 rebuilds this tab.
struct ProgressTab: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var weekEnding = CareDay.containing(.now)
    @State private var report: WeeklyReport?
    @State private var file: URL?
    @State private var problem: String?

    private var isThisWeek: Bool { weekEnding >= CareDay.containing(.now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LedgerSection("Weekly card") {
                        weekRow
                    }

                    preview
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.ledeToSection)

                    if let child = model.child {
                        LedgerSection("For a visit", footnote: "A PDF of every log over a few weeks, for a provider.") {
                            NavigationLink {
                                DoctorReportView(child: child)
                            } label: {
                                NavigationRow(title: "Doctor report")
                            }
                            .buttonStyle(.ledger)
                        }
                        .padding(.top, Spacing.section)
                    }

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
            .logConfirmation(on: .progress)
            .shellToolbar(showsSwitcher: true)
        }
        .task(id: "\(model.child?.id.uuidString ?? "")-\(weekEnding)") { await build() }
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

    private func build() async {
        guard let child = model.child, let container = try? CaliCareModelContainer.shared() else { return }
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

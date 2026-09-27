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
                    AppHeader(title: "Progress")
                    if let report {
                        SummaryCard(
                            eyebrow: report.dateRange(),
                            title: report.headline.text,
                            caption: report.worthWatching.map { "Worth watching: \($0.prefix(1).lowercased())\($0.dropFirst())" },
                            art: .flower
                        )
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x5)

                        WeekGrid(days: report.days)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x6)
                    }

                    if let child = model.child {
                        VStack(spacing: Spacing.x2) {
                            NavigationLink {
                                DoctorReportView(child: child)
                            } label: {
                                Text("Share with provider")
                                    .font(TypeStyle.section.font)
                                    .foregroundStyle(palette.ink)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.ink, lineWidth: 1))
                            }
                            if let file {
                                ShareLink(item: file) {
                                    Text("Share this week’s card")
                                        .textStyle(.body)
                                        .foregroundStyle(palette.indigo)
                                        .frame(minHeight: Size.touchTarget)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x6)
                    }
                    if let problem {
                        Text(problem)
                            .textStyle(.body)
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, Spacing.margin)
                    }
                }
                .padding(.bottom, BottomBar.clearance)
            }
            .paperBackground()
            .toolbar(.hidden, for: .navigationBar)
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

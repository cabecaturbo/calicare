import Core
import SwiftData
import SwiftUI

/// Progress: Week or Month (UX.md §6), each a summary card and a grid, then
/// Share with provider for the chosen range. "Since visit" joins once visits
/// exist (Phase 4).
struct ProgressTab: View {
    enum Span: String, CaseIterable {
        case week = "Week", month = "Month"
    }

    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    private var weekEnding: CareDay { CareDay.containing(.now) }
    @State private var span: Span = .week
    @State private var showingCaregiverCard = false
    @State private var changes: [CareChange] = []
    @State private var rougherSince: CareDay?
    @State private var report: WeeklyReport?
    @State private var monthReport: MonthlyReport?
    @State private var file: URL?
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "Progress")
                    Picker("Range", selection: $span) {
                        ForEach(Span.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x4)

                    if span == .month, let monthReport {
                        SummaryCard(
                            eyebrow: monthReport.title(),
                            title: monthReport.headline.text,
                            caption: monthReport.worthWatching.map { "Worth watching: \($0.prefix(1).lowercased())\($0.dropFirst())" },
                            art: .tree
                        )
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x5)

                        MonthGrid(days: monthReport.days)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x6)
                    } else if span == .week, let report {
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

                    if !changes.isEmpty || rougherSince != nil {
                        ChangesSection(changes: changes, rougherSince: rougherSince)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x6)
                    }

                    if let child = model.child {
                        VStack(spacing: Spacing.x2) {
                            NavigationLink {
                                DoctorReportView(child: child, range: shareRange)
                            } label: {
                                Text("Share with provider")
                                    .font(TypeStyle.section.font)
                                    .foregroundStyle(palette.ink)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.ink, lineWidth: 1))
                            }
                            Button {
                                showingCaregiverCard = true
                            } label: {
                                Text("Caregiver card")
                                    .textStyle(.body)
                                    .foregroundStyle(palette.indigo)
                                    .frame(minHeight: Size.touchTarget)
                            }
                            .accessibilityHint("A card for a sitter or grandparent, in your words.")
                            if span == .week, let file {
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
        .sheet(isPresented: $showingCaregiverCard) {
            if let child = model.child {
                CaregiverCardSheet(
                    child: child,
                    eveningSteps: model.routineSteps.filter { $0.time == .evening && $0.isActive }.map(\.name)
                )
                .nightAwarePalette()
            }
        }
    }

    /// The doctor report covers what's on screen: this week or this month.
    private var shareRange: DoctorReport.Range? {
        switch span {
        case .week: report.map { DoctorReport.Range(first: $0.weekEnding.adding(days: -6), last: $0.weekEnding) }
        case .month: monthReport?.range
        }
    }

    /// Care changes (plans, supplements, patch tests) and whether the last
    /// few days turned rougher than the week before them.
    private func loadChanges(child: ChildInfo, container: ModelContainer, today: CareDay) async {
        let plans = CarePlanStore(modelContainer: container)
        let logs = LogStore(modelContainer: container)
        guard let all = try? await plans.plans(child: child.id).filter({ $0.status != .draft }),
              let live = try? await logs.allLive()
        else { return }
        var items: [UUID: PlanItemInfo] = [:]
        for plan in all {
            for item in (try? await plans.items(plan: plan.id)) ?? [] { items[item.id] = item }
        }
        changes = CareChanges.list(plans: all, items: items, logs: live.filter { $0.childID == child.id })
        let events = (try? await logs.events(from: today.adding(days: -13), through: today, child: child.id)) ?? []
        let days = (0..<14).reversed().map { WeekDay(summary: DaySummary(day: today.adding(days: -$0), events: events)) }
        rougherSince = CareChanges.rougherSince(days)
    }

    private func build() async {
        guard let child = model.child, let container = try? CaliCareModelContainer.shared() else { return }
        do {
            let report = try await WeeklyReport.load(child: child, weekEnding: weekEnding, container: container)
            self.report = report
            let today = CareDay.containing(.now)
            monthReport = try await MonthlyReport.load(child: child, year: today.year, month: today.month, container: container)
            file = try WeeklyCardRenderer.file(for: report)
            await loadChanges(child: child, container: container, today: today)
            problem = nil
        } catch {
            problem = "Couldn't make the card just now. Try again in a moment."
        }
    }
}

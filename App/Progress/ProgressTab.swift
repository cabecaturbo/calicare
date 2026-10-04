import Core
import SwiftData
import SwiftUI

/// How it's going: Week, Month, or Since the visit. One big statement (is it
/// getting better?), the grid in skin colors, then sharing with the doctor.
struct ProgressTab: View {
    enum Span: String, CaseIterable {
        case week = "Week", month = "Month", sinceVisit = "Since the visit"
    }

    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    private var weekEnding: CareDay { CareDay.containing(.now) }
    @State private var span: Span = .week
    @State private var showingCaregiverCard = false
    @State private var changes: [CareChange] = []
    @State private var lastVisit: VisitInfo?
    @State private var sinceVisitDays: [WeekDay] = []
    @State private var rougherSince: CareDay?
    @State private var report: WeeklyReport?
    @State private var monthReport: MonthlyReport?
    @State private var file: URL?
    @State private var problem: String?

    /// Headlines read as a sentence: "Calmer than last week."
    static func sentence(_ text: String) -> String {
        guard let last = text.last, !".!?".contains(last) else { return text }
        return text + "."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppHeader(title: "How it’s going", why: "See if \(model.child?.name ?? "your child")’s skin is getting better.")
                    Picker("Range", selection: $span) {
                        ForEach(Span.allCases.filter { $0 != .sinceVisit || lastVisit != nil }, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.margin)
                    .padding(.top, Spacing.x5)

                    if span == .sinceVisit, let lastVisit {
                        BigStatement(
                            text: "\(sinceVisitDays.filter { $0.nightRating == .good }.count) good nights out of \(sinceVisitDays.count).",
                            line: "Since the \(lastVisit.date.formatted(.dateTime.month(.abbreviated).day())) visit."
                        )
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x6)

                        MonthGrid(days: sinceVisitDays, title: "Since the visit")
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x6)
                    } else if span == .month, let monthReport {
                        BigStatement(text: Self.sentence(monthReport.headline.text), line: monthReport.title())
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x6)

                        MonthGrid(days: monthReport.days)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x6)
                        WorthWatching(text: monthReport.worthWatching)
                    } else if span == .week, let report {
                        BigStatement(text: Self.sentence(report.headline.text), line: report.dateRange())
                        .padding(.horizontal, Spacing.margin)
                        .padding(.top, Spacing.x6)

                        WeekGrid(days: report.days)
                            .padding(.horizontal, Spacing.margin)
                            .padding(.top, Spacing.x6)
                        WorthWatching(text: report.worthWatching)
                    }

                    if let child = model.child {
                        PhotosSection(child: child)
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
                                Text("Share with \(child.name)’s doctor")
                                    .font(TypeStyle.label.font)
                                    .foregroundStyle(palette.ink)
                                    .frame(maxWidth: .infinity, minHeight: Size.button(isNight: palette.isNight))
                                    .overlay(RoundedRectangle(cornerRadius: Corner.control).strokeBorder(palette.ink, lineWidth: 1))
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
                .padding(.bottom, Spacing.x5)
            }
            .paperBackground()
            .statusBarBackground()
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
        case .sinceVisit: lastVisit.map { DoctorReport.Range(first: CareDay.containing($0.date), last: CareDay.containing(.now)) }
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
        let foods = (try? await FoodStore(modelContainer: container).foods(child: child.id)) ?? []
        let products = (try? await ProductStore(modelContainer: container).products(child: child.id)) ?? []
        changes = CareChanges.list(plans: all, items: items, logs: live.filter { $0.childID == child.id }, foods: foods,
                                   products: products)
        let events = (try? await logs.events(from: today.adding(days: -13), through: today, child: child.id)) ?? []
        let days = (0..<14).reversed().map { WeekDay(summary: DaySummary(day: today.adding(days: -$0), events: events)) }
        rougherSince = CareChanges.rougherSince(days)

        lastVisit = try? await plans.lastVisit(child: child.id)
        if let lastVisit {
            let first = CareDay.containing(lastVisit.date)
            let since = (try? await logs.events(from: first, through: today, child: child.id)) ?? []
            var all: [WeekDay] = []
            var day = first
            while day <= today, all.count < 370 {
                all.append(WeekDay(summary: DaySummary(day: day, events: since)))
                day = day.adding(days: 1)
            }
            sinceVisitDays = all
        } else {
            sinceVisitDays = []
            if span == .sinceVisit { span = .week }
        }
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

/// "Worth watching: two flares on Tuesday." under the grid, when there's one.
private struct WorthWatching: View {
    @Environment(\.palette) private var palette
    let text: String?

    var body: some View {
        if let text {
            Text("Worth watching: \(text.prefix(1).lowercased())\(text.dropFirst())")
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.margin)
                .padding(.top, Spacing.x4)
        }
    }
}

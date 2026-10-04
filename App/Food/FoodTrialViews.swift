import Core
import SwiftUI

/// A running trial: today's day and amount, "Gave it today", a one-tap "Worth
/// watching", skin and nights across the trial and the day after, and ending it
/// with the parent's choice.
struct FoodTrialView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let foodID: UUID
    @State private var days: [WeekDay] = []
    @State private var ending = false

    private var trial: FoodTrial? { model.foodTrials.first { $0.food.id == foodID } }

    var body: some View {
        ScrollView {
            if let trial {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    header(trial)
                    actions(trial)
                    watch(trial)
                    if trial.isRunning {
                        Button("End the trial") { ending = true }
                            .buttonStyle(.textLink)
                    }
                    Text("Reactions can show up 12–24 hours later, so the day after the trial is shown too. Not medical advice.")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.x5)
            }
        }
        .paperBackground()
        .solidNavigationBar(.paper)
        .navigationTitle(trial?.food.name ?? "Trial")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("How did it go?", isPresented: $ending, titleVisibility: .visible) {
            if let trial {
                Button("Safe") { Task { await model.endTrial(trial, as: .safe) } }
                Button("Keep testing") { Task { await model.endTrial(trial, as: .testing) } }
                Button("Paused") { Task { await model.endTrial(trial, as: .paused) } }
            }
        } message: {
            Text("You decide where \(trial?.food.name ?? "it") goes on the list.")
        }
        .task(id: trial?.started) { await loadDays() }
    }

    private func header(_ trial: FoodTrial) -> some View {
        let day = trial.day(at: .now)
        return VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(trial.isRunning ? (day <= trial.days ? "Day \(day) of \(trial.days)" : "Trial days done") : "Trial ended")
                .textStyle(.title)
                .foregroundStyle(palette.ink)
            if trial.isRunning, let step = trial.step(at: .now) {
                Text("Today: \(step)").textStyle(.body).foregroundStyle(palette.ink)
            }
            Text("Started \(trial.started.formatted(.dateTime.month(.abbreviated).day()))")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
        }
    }

    @ViewBuilder
    private func actions(_ trial: FoodTrial) -> some View {
        if trial.isRunning {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                Button(trial.givenToday(at: .now) ? "Given today" : "Gave it today") {
                    Task { await model.logTrial(.given, trial.food) }
                }
                .buttonStyle(.primary)
                .disabled(trial.givenToday(at: .now))
                Button("Something worth watching") { Task { await model.logTrial(.worthWatching, trial.food) } }
                    .buttonStyle(.textLink)
            }
        }
    }

    /// Each day: the date, skin, night, whether it was given, and anything noted.
    private func watch(_ trial: FoodTrial) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Skin and nights")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .padding(.bottom, Spacing.x2)
            ForEach(days) { day in
                let interval = day.day.interval()
                let given = trial.given.contains { interval.contains($0) }
                let noted = trial.worthWatching.contains { interval.contains($0.timestamp) }
                HStack(spacing: Spacing.x4) {
                    Text(day.day.noon().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                        .frame(width: 110, alignment: .leading)
                    if let skin = day.skin { SkinSwatch(answer: skin, size: 16) } else { dash }
                    if let night = day.night {
                        Circle().fill(palette.color(for: night)).overlay(Circle().strokeBorder(palette.graphite, lineWidth: 1))
                            .frame(width: 12, height: 12)
                    } else { dash }
                    Spacer()
                    Text([given ? "Given" : nil, noted ? "Worth watching" : nil].compactMap { $0 }.joined(separator: " · "))
                        .textStyle(.meta)
                        .foregroundStyle(noted ? palette.ochre : palette.graphite)
                }
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
            }
        }
    }

    private var dash: some View {
        Capsule().fill(palette.graphite).frame(width: 10, height: 2).frame(width: 16)
    }

    private func loadDays() async {
        guard let trial, let child = model.child, let container = try? CaliCareModelContainer.shared() else { return }
        let watchDays = trial.watchDays()
        guard let first = watchDays.first, let last = watchDays.last else { return }
        let events = (try? await LogStore(modelContainer: container).events(from: first, through: last, child: child.id)) ?? []
        days = watchDays.filter { $0 <= CareDay.containing(.now) }.map { WeekDay(summary: DaySummary(day: $0, events: events)) }
    }
}

/// Start a trial: how many days, and optional amounts per day, as the plan or
/// parent decides. Nothing is suggested.
struct StartTrialSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(TodayModel.self) private var model
    let food: FoodInfo
    @State private var days = 3
    @State private var steps = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("\(days) day\(days == 1 ? "" : "s")", value: $days, in: 1...21)
                } footer: {
                    Text("As your plan or doctor says.")
                }
                Section {
                    TextField("Amounts, one per day (optional)", text: $steps, axis: .vertical)
                        .lineLimit(2...6)
                } footer: {
                    Text("For example the first day's amount, then the next. Leave empty if there's no schedule.")
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground(.oat)
            .solidNavigationBar()
            .navigationTitle("Trial: \(food.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let (days, steps) = (days, steps.split(whereSeparator: \.isNewline).map(String.init))
                        dismiss()
                        Task { await model.startTrial(food, days: days, steps: steps) }
                    }
                }
            }
        }
        .tint(palette.indigo)
        .presentationDetents([.medium, .large])
    }
}

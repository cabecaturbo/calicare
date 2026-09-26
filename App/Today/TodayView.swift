import Core
import SwiftUI

/// The child's day at a glance: last night, one-tap logging, today's timeline, and the week.
struct TodayView: View {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ReminderController.self) private var reminders
    @State private var model = TodayModel()
    @State private var showingSettings = false
    @State private var showingAddChild = false
    @State private var editing: LogEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                TodayHeader(
                    children: model.children,
                    child: model.child,
                    onSelect: { id in Task { await model.select(id) } },
                    onAddChild: { showingAddChild = true },
                    onSettings: { showingSettings = true }
                )

                if model.child != nil {
                    if let report = model.lastNight {
                        LastNightCard(report: report)
                    }
                    LogButtons(isDaytime: model.isDaytime) { type, value in
                        Task { await model.log(type, value: value) }
                    }
                    TodayTimeline(model: model, isDaytime: model.isDaytime) { editing = $0 }
                    WeekStrip(days: model.week)
                } else if model.hasLoaded {
                    noChild
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.l)
        }
        .background(palette.background.ignoresSafeArea())
        .refreshable { await model.load() }
        .safeAreaInset(edge: .bottom) {
            if let confirmation = model.confirmation {
                LoggedBanner(confirmation: confirmation) {
                    Task { await model.undo(confirmation) }
                } onDismiss: {
                    model.confirmation = nil
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.confirmation)
        .sensoryFeedback(.success, trigger: model.confirmation?.id) { _, new in new != nil }
        .sheet(isPresented: $showingSettings, onDismiss: reload) {
            SettingsView()
                .environment(reminders)
                .nightAwarePalette()
        }
        .sheet(isPresented: $showingAddChild, onDismiss: reload) {
            AddChildSheet()
                .nightAwarePalette()
        }
        .sheet(item: $editing, onDismiss: reload) { entry in
            EditLogSheet(entry: entry, model: model)
                .nightAwarePalette()
        }
        .sheet(isPresented: firstLogOffer) {
            ReminderOfferSheet(
                onTurnOn: { Task { await reminders.acceptOffer() } },
                onNotNow: { reminders.declineOffer() }
            )
        }
        .alert("Something went wrong", isPresented: problemShowing) {
            Button("OK", role: .cancel) { model.problem = nil }
        } message: {
            Text(model.problem ?? "")
        }
        .task {
            await model.load()
            await offerRemindersIfNeeded()
        }
        .task {
            // Picks up logs from widgets and Siri, and the 7 PM switch to tonight.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                await model.load()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await model.load()
                    await offerRemindersIfNeeded()
                }
            }
        }
        .onChange(of: model.confirmation) { _, confirmation in
            // Right after the first log is a sensible moment to offer reminders.
            if confirmation != nil {
                Task { await offerRemindersIfNeeded() }
            }
        }
    }

    private var noChild: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Add your child to start logging.")
                .font(Typography.body)
                .foregroundStyle(palette.ink)
            PrimaryButton(title: "Add a child") { showingAddChild = true }
        }
        .cardStyle()
    }

    private func reload() {
        Task { await model.load() }
    }

    /// The one-time reminders offer, after something has been logged. Swiping it away counts as "Not now".
    private var firstLogOffer: Binding<Bool> {
        Binding(
            get: { reminders.offer == .firstLog },
            set: { isShowing in
                if !isShowing, reminders.offer == .firstLog { reminders.declineOffer() }
            }
        )
    }

    private var problemShowing: Binding<Bool> {
        Binding(
            get: { model.problem != nil },
            set: { if !$0 { model.problem = nil } }
        )
    }

    private func offerRemindersIfNeeded() async {
        guard !showingSettings, !showingAddChild, editing == nil else { return }
        await reminders.offerAfterFirstLogIfNeeded()
    }
}

#Preview("Day") {
    TodayView()
        .environment(ReminderController())
        .environment(\.palette, .day)
        .onAppear { FontRegistry.registerAll() }
}

#Preview("Night") {
    TodayView()
        .environment(ReminderController())
        .environment(\.palette, .night)
        .onAppear { FontRegistry.registerAll() }
}

import Core
import SwiftUI

/// The child's day at a glance: last night, one-tap logging, today's timeline, and the week.
struct TodayView: View {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ReminderController.self) private var reminders
    @State private var model = TodayModel()
    @State private var showingSettings = false
    @State private var showingAddChild = false
    @State private var editing: LogEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Spacing.titleToLede) {
                    TodayHeader(
                        children: model.children,
                        child: model.child,
                        onSelect: { id in Task { await model.select(id) } },
                        onAddChild: { showingAddChild = true },
                        onSettings: { showingSettings = true }
                    )
                    if model.child != nil, let report = model.lastNight {
                        LastNightLede(report: report)
                    }
                }
                .padding(.horizontal, Spacing.margin)

                if model.child != nil {
                    VStack(alignment: .leading, spacing: Spacing.section) {
                        LogButtons(isDaytime: model.isDaytime, entries: model.entries, lastNight: model.lastNight) { type, value in
                            Task { await model.log(type, value: value) }
                        }
                        TodayTimeline(model: model, isDaytime: model.isDaytime) { editing = $0 }
                        WeekStrip(days: model.week)
                    }
                    .padding(.top, Spacing.ledeToSection)
                } else if model.hasLoaded {
                    noChild
                        .padding(.top, Spacing.ledeToSection)
                }
            }
            .padding(.top, Spacing.x2)
            .padding(.bottom, Spacing.section)
        }
        .paperBackground()
        .refreshable { await model.load() }
        .safeAreaInset(edge: .bottom) {
            if let confirmation = model.confirmation {
                LoggedBanner(confirmation: confirmation) {
                    Task { await model.undo(confirmation) }
                } onDismiss: {
                    model.confirmation = nil
                }
                .padding(.horizontal, Spacing.x4)
                .padding(.bottom, Spacing.x2)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.confirmation)
        .sensoryFeedback(.impact(weight: .light), trigger: model.confirmation?.id) { _, new in new != nil }
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
        .alert(model.problem ?? "", isPresented: problemShowing) {
            Button("OK", role: .cancel) { model.problem = nil }
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
        .onChange(of: model.confirmation) { old, new in
            // Right after the first log is a sensible moment to offer reminders:
            // once its confirmation has gone, so the offer never hides Undo.
            if old != nil, new == nil {
                Task { await offerRemindersIfNeeded() }
            }
        }
    }

    private var noChild: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("Add your child to start logging.")
                .textStyle(.body)
                .foregroundStyle(palette.ink)
            Button("Add a child") { showingAddChild = true }
                .buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.margin)
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

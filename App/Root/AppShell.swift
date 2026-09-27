import Core
import SwiftUI

/// Today, Plan, and Progress. Owns the shared day (one `TodayModel`), Settings,
/// adding a child, the log sheet, and the quick log bar on Plan and Progress.
struct AppShell: View {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ReminderController.self) private var reminders
    @Environment(AccountController.self) private var account
    @Environment(SyncController.self) private var sync
    @State private var model = TodayModel()
    @State private var shell = Shell()

    var body: some View {
        @Bindable var shell = shell
        TabView(selection: $shell.tab) {
            // The system tab bar is hidden; BottomBar draws the canvas's pill and log control.
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView()
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab("Plan", systemImage: "list.bullet.clipboard", value: AppTab.plan) {
                PlanView()
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressTab()
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .tint(palette.indigo)
        .overlay(alignment: .bottom) { BottomBar() }
        .sensoryFeedback(.impact(weight: .light), trigger: model.confirmation?.id) { _, new in new != nil }
        .sheet(isPresented: $shell.showingSettings, onDismiss: reload) {
            SettingsView()
                .environment(reminders)
                .environment(account)
                .environment(sync)
                .presentationDetents([.large])
                .nightAwarePalette()
        }
        .sheet(isPresented: $shell.showingAddChild, onDismiss: reload) {
            AddChildSheet()
                .nightAwarePalette()
        }
        .sheet(isPresented: $shell.showingNote) {
            NoteSheet()
                .nightAwarePalette()
        }
        .onOpenURL { url in
            if DeepLink.isNote(url) { shell.showingNote = true }
        }
        .sheet(isPresented: $shell.showingLog) {
            LogSheet()
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
        .onReceive(NotificationCenter.default.publisher(for: .caliCareRemoteDataChanged)) { _ in reload() }
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
        // Last, so the tabs, the accessory, and every sheet share them.
        .environment(model)
        .environment(shell)
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
        guard !shell.showingSettings, !shell.showingAddChild, !shell.showingLog, !shell.showingNote else { return }
        await reminders.offerAfterFirstLogIfNeeded()
    }
}

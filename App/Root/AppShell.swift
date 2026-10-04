import Core
import SwiftUI

/// Today, To do, How it's going, Care plan: four native tabs, with Itchy's dock
/// above the tab bar on every one. Owns the shared day (one `TodayModel`),
/// Settings, adding a child, More, and the log sheets.
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
        tabs
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
        .sheet(isPresented: $shell.showingMore, onDismiss: runPendingMore) {
            MoreSheet { shell.pendingMore = $0 }
                .nightAwarePalette()
        }
        .sheet(item: $shell.choosing) { choice in
            ChoiceSheet(choice: choice)
                .nightAwarePalette()
        }
        .sheet(item: $shell.addingWhere) { entry in
            BodyAreaSheet(entry: entry)
                .nightAwarePalette()
        }
        .alert(model.problem ?? "", isPresented: problemShowing) {
            Button("OK", role: .cancel) { model.problem = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .caliCareRemoteDataChanged)) { _ in reload() }
        .task { await model.load() }
        .task {
            // Picks up logs from widgets and Siri, and the 7 PM switch to tonight.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                await model.load()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
        // Last, so the tabs, the accessory, and every sheet share them.
        .environment(model)
        .environment(shell)
    }

    private var tabs: some View {
        @Bindable var shell = shell
        return TabView(selection: $shell.tab) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView()
                    .itchyDock(isNightToday: palette.isNight)
            }
            Tab("To do", systemImage: "checklist", value: AppTab.todo) {
                TodoView()
                    .itchyDock()
            }
            Tab("How it’s going", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressTab()
                    .itchyDock()
            }
            Tab("Care plan", systemImage: "book.closed", value: AppTab.info) {
                InfoView()
                    .itchyDock()
            }
        }
        .tint(palette.indigo)
    }

    /// Runs what was picked in More once its sheet is gone, so the next sheet can show.
    private func runPendingMore() {
        guard let choice = shell.pendingMore else { return }
        shell.pendingMore = nil
        switch choice {
        case .flare: Task { await model.log(.flare) }
        case .bowel: shell.choosing = .bowel
        case .mood: shell.choosing = .mood
        case .note: shell.showingNote = true
        }
    }

    private func reload() {
        Task { await model.load() }
    }

    private var problemShowing: Binding<Bool> {
        Binding(
            get: { model.problem != nil },
            set: { if !$0 { model.problem = nil } }
        )
    }
}

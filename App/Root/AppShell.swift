import Core
import SwiftUI

/// Today, To do, Progress, and Plan. Owns the shared day (one `TodayModel`), Settings,
/// adding a child, the log sheet, and the quick log bar on every tab.
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
            if DeepLink.isProgress(url) { shell.tab = .progress }
            if DeepLink.isNight(url) { shell.showingNight = true }
            if DeepLink.isQuickLog(url) {
                shell.tab = .today
                if !QuickLogCard.isRunning { shell.startingQuickLog = true }
            }
        }
        .sheet(isPresented: $shell.showingNight) {
            NightSummarySheet()
                .nightAwarePalette()
        }
        .quickLogCardStarter()
        .sheet(isPresented: $shell.showingLog) {
            LogSheet()
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

    /// Apple's glass tab bar with the round Log button (iOS 26.1 and later);
    /// older phones keep our own pills.
    private var usesGlassBar: Bool {
        if #available(iOS 26.1, *) { return true }
        return false
    }

    @ViewBuilder
    private var tabs: some View {
        let pills = !usesGlassBar
        let view = TabView(selection: tabSelection) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView()
                    .modifier(TabChrome(pills: pills))
            }
            Tab("To do", systemImage: "checklist", value: AppTab.todo) {
                TodoView()
                    .modifier(TabChrome(pills: pills))
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.progress) {
                ProgressTab()
                    .modifier(TabChrome(pills: pills))
            }
            Tab("Plan", systemImage: "heart.text.clipboard", value: AppTab.plan) {
                PlanTab()
                    .modifier(TabChrome(pills: pills))
            }
            if !pills {
                Tab(value: AppTab.logItchy, role: circleRole) {
                    Color.clear
                } label: {
                    Label { Text("Log") } icon: { Image(uiImage: LogTabIcon.image) }
                }
                .accessibilityLabel("Log itching")
            }
        }
        .tint(palette.accent)

        if pills {
            // The system tab bar is hidden; BottomBar draws the pills and log control.
            view.overlay(alignment: .bottom) { BottomBar() }
        } else if #available(iOS 26.0, *) {
            view.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            view
        }
    }

    /// The role that sets a tab apart as a circle: `.search` on iOS 26,
    /// `.prominent` from iOS 27.
    private var circleRole: TabRole {
        #if compiler(>=6.4) // Xcode 27: the iOS 27 SDK has .prominent
        if #available(iOS 27.0, *) { return .prominent }
        #endif
        return .search
    }

    /// The circle "tab" logs itching and stays on the current tab.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { shell.tab },
            set: { new in
                if new == .logItchy {
                    Task { await model.log(.itchEpisode) }
                } else {
                    shell.tab = new
                }
            }
        )
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

/// Per tab: with our pills the system tab bar hides; with the glass bar the
/// Logged line sits above it.
private struct TabChrome: ViewModifier {
    let pills: Bool

    func body(content: Content) -> some View {
        Group {
            if pills {
                content.toolbar(.hidden, for: .tabBar)
            } else {
                content.modifier(LoggedBannerInset(isOn: true))
            }
        }
    }
}

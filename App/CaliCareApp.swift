import Core
import SwiftUI

@main
struct CaliCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var reminders = ReminderController()
    @State private var account: AccountController
    @State private var sync: SyncController

    init() {
        let account = AccountController()
        _account = State(initialValue: account)
        _sync = State(initialValue: SyncController(account: account))
        FontRegistry.registerAll()
        #if DEBUG
        DesignReviewLaunch.apply()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .nightAwarePalette()
                .environment(reminders)
                .environment(account)
                .environment(sync)
                .task {
                    account.start()
                    sync.start()
                }
                .onChange(of: account.state) { _, state in
                    switch state {
                    case .signedIn: sync.requestSync(after: .zero)
                    case .signedOut: sync.accountSignedOut()
                    case .expired: break
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshReminders() }
                sync.requestSync(after: .zero)
            }
        }
        .backgroundTask(.appRefresh(SyncController.backgroundTaskID)) {
            await account.loadStoredSession()
            await sync.syncNow()
        }
    }

    /// Keeps reminders current: a new day, a changed child, or permission changed in iOS Settings.
    private func refreshReminders() async {
        await reminders.reload()
        try? await ReminderScheduler.live().refresh()
    }
}

import Core
import SwiftUI

@main
struct CaliCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var reminders = ReminderController()
    @State private var account = AccountController()

    init() {
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
                .task { account.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshReminders() }
            }
        }
    }

    /// Keeps reminders current: a new day, a changed child, or permission changed in iOS Settings.
    private func refreshReminders() async {
        await reminders.reload()
        try? await ReminderScheduler.live().refresh()
    }
}

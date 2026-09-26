import Core
import SwiftUI

@main
struct CaliCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var reminders = ReminderController()

    init() {
        FontRegistry.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .nightAwarePalette()
                .environment(reminders)
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

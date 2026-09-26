import Core
import SwiftUI

@main
struct CaliCareApp: App {
    init() {
        FontRegistry.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
                .nightAwarePalette()
                .task { await seedForDebug() }
        }
    }

    private func seedForDebug() async {
        #if DEBUG
        await DebugSeed.addSampleChildIfNeeded()
        #endif
    }
}

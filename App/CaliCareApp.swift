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
        }
    }
}

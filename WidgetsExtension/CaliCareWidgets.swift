import AppIntents
import Core
import SwiftUI
import WidgetKit

@main
struct CaliCareWidgets: WidgetBundle {
    init() {
        FontRegistry.registerAll()
    }

    var body: some Widget {
        ItchWidget()
        QuickLogWidget()
        LastNightWidget()
        LogItchControl()
        NightStripWidget()
        TonightLiveActivity()
        LockScreenTestLiveActivity()
    }
}

/// Pulls Core's intents into the extension so widgets and controls can run them.
struct WidgetsIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [CoreIntentsPackage.self]
    }
}

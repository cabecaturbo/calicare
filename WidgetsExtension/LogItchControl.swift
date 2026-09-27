import AppIntents
import Core
import SwiftUI
import WidgetKit

/// Control Center button that logs an itch for the current child. Also usable on the Action Button.
struct LogItchControl: ControlWidget {
    static let kind = "com.cursorkittens.calicare.widgets.log-itch"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LogItchIntent()) {
                Label("Log Itchy", systemImage: "hand.raised")
            }
        }
        .displayName("Log Itchy")
        .description("Logs an itchy moment for your current child.")
    }
}

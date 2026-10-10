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
                Label("Log", systemImage: "hand.raised.fill")
            }
        }
        // Found by searching "Cali Care" in Control Center; the guide says "tap Log".
        .displayName("Log")
        .description("Logs an itch for your current child.")
    }
}

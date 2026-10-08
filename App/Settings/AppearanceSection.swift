import Core
import SwiftUI
import WidgetKit

/// Settings › Appearance: night colors follow the clock (8 PM to 7 AM) unless
/// the parent picks day or night here.
struct AppearanceSection: View {
    @Environment(\.palette) private var palette
    @AppStorage(AppearanceMode.key, store: AppGroup.defaults) private var raw = AppearanceMode.automatic.rawValue

    var body: some View {
        SettingsSection("Appearance", footnote: "Time of day uses night colors from 8 PM to 7 AM.") {
            Picker(selection: Binding(get: { AppearanceMode(rawValue: raw) ?? .automatic }, set: set)) {
                Text("Time of day").tag(AppearanceMode.automatic)
                Text("Day").tag(AppearanceMode.day)
                Text("Night").tag(AppearanceMode.night)
            } label: {
                SettingsLabel("Colors")
            }
            .tint(palette.accent)
        }
    }

    private func set(_ mode: AppearanceMode) {
        AppearanceMode.current = mode
        raw = mode.rawValue
        WidgetCenter.shared.reloadAllTimelines()
        Task { await QuickLogCard.refresh() }
    }
}

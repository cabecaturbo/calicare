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
            // Bound straight to the stored value: Xcode 26's compiler crashed on a
            // custom Binding whose setter was a method here.
            Picker(selection: $raw) {
                Text("Time of day").tag(AppearanceMode.automatic.rawValue)
                Text("Day").tag(AppearanceMode.day.rawValue)
                Text("Night").tag(AppearanceMode.night.rawValue)
            } label: {
                SettingsLabel("Colors")
            }
            .tint(palette.accent)
            .onChange(of: raw) { _, _ in refresh() }
        }
    }

    /// Widgets and the Lock Screen card follow the new colors.
    private func refresh() {
        WidgetCenter.shared.reloadAllTimelines()
        Task { await QuickLogCard.refresh() }
    }
}

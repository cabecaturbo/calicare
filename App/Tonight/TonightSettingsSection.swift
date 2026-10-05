import Core
import SwiftUI

/// Settings › Tonight: one switch. Turning it off takes the card off the Lock Screen.
struct TonightSettingsSection: View {
    @Environment(\.palette) private var palette
    @State private var isOn = TonightSettings().isEnabled

    var body: some View {
        SettingsSection(
            "Tonight",
            footnote: "Tonight lasts up to 8 hours after your last tap. The Lock Screen shows only how many times your child woke up, never a name."
        ) {
            Toggle(isOn: $isOn) {
                SettingsLabel("Show Tonight on the Lock Screen")
            }
            .tint(palette.indigo)
            .onChange(of: isOn) { _, on in
                TonightSettings().isEnabled = on
                if !on { Task { await Tonight.endAll() } }
            }
        }
    }
}

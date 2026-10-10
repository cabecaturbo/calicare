import AppIntents
import Core
import SwiftUI

/// Settings › Widgets and Siri › "Send the weekly card on its own": how to set
/// up a Shortcuts automation with "Get Weekly Card". Numbered steps until the
/// screens are recorded on a real iPhone; iOS's own Shortcuts button opens the app.
struct AutoSendGuide: View {
    @Environment(\.palette) private var palette

    private let steps = [
        "Open Shortcuts, tap Automation, then tap +.",
        "Tap Time of Day. Pick 7:00 PM, Weekly, Sunday, and Run Immediately. Tap Next.",
        "Tap New Blank Automation, then Add Action. Search for Cali Care and tap Get Weekly Card.",
        "Search for Send Message, add it, and pick who gets the card. Tap Done.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                Text("Each Sunday night, your phone can send this week's card to your partner or a grandparent. It takes a minute to set up in Apple's Shortcuts app.")
                    .textStyle(.body)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Spacing.x4) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.x4) {
                            Text("\(index + 1)")
                                .textStyle(.label)
                                .foregroundStyle(palette.accent)
                                .frame(width: 20, alignment: .leading)
                            Text(step)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                ShortcutsLink()
                    .shortcutsLinkStyle(palette.isNight ? .dark : .light)

                Text("\"Get Care Log\" works the same way for your provider: add it instead, then Send Email. The care log says it isn't medical advice on every page.")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.x5)
        }
        .paperBackground()
        .navigationTitle("Send the card weekly")
        .navigationBarTitleDisplayMode(.inline)
    }
}

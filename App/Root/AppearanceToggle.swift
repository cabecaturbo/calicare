import Core
import SwiftUI
import WidgetKit

/// The day/night toggle: a small sun or moon that stays put while the page
/// scrolls. A tap switches to the other colors and keeps them; press and hold
/// for "Match the time of day". Only the colors change: the night layout
/// still follows the clock.
struct AppearanceToggle: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            set(palette.isNight ? .day : .night)
        } label: {
            Image(systemName: palette.isNight ? "sun.max" : "moon")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.ink)
                .frame(width: Size.touchTarget, height: Size.touchTarget)
                .background(palette.oat, in: Circle())
                .overlay(Circle().strokeBorder(palette.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(palette.isNight ? "Switch to day colors" : "Switch to night colors")
        .contextMenu {
            Button("Day colors", systemImage: "sun.max") { set(.day) }
            Button("Night colors", systemImage: "moon") { set(.night) }
            Button("Match the time of day", systemImage: "clock") { set(.automatic) }
        }
    }

    private func set(_ mode: AppearanceMode) {
        AppearanceMode.current = mode
        UserDefaults(suiteName: AppGroup.identifier)?.set(mode.rawValue, forKey: AppearanceMode.key)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await QuickLogCard.refresh() }
    }
}

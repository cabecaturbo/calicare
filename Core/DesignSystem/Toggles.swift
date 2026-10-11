import SwiftUI

/// Switches with an off track that stands out from the paper (at least 3:1,
/// DESIGN.md §3). The system's off track is about 1.35:1 on our paper.
/// On is the accent. VoiceOver still sees a standard switch.
public struct CaliToggleStyle: ToggleStyle {
    public init() {}

    /// Off track: 3.4:1 on day paper (#F6EEE2), 3.4:1 on night paper (#201712).
    static let offDay = Color(hex: 0x8F7F6D)
    static let offNight = Color(hex: 0x7A6A5A)

    public func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration)
    }

    private struct Styled: View {
        @Environment(\.palette) private var palette
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration

        var body: some View {
            HStack(spacing: Spacing.x4) {
                configuration.label
                Spacer(minLength: 0)
                track
            }
            .contentShape(Rectangle())
            .onTapGesture { withMotion(.quick) { configuration.isOn.toggle() } }
            .opacity(isEnabled ? 1 : 0.4)
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
            }
        }

        private var track: some View {
            let off = palette.isNight ? CaliToggleStyle.offNight : CaliToggleStyle.offDay
            return Capsule()
                .fill(configuration.isOn ? palette.accent : off)
                .frame(width: 51, height: 31)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(palette.isNight ? palette.ink : Color.white)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .padding(2)
                }
        }
    }
}

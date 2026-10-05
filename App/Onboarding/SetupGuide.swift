import Core
import SwiftUI

/// One step of setup that happens outside the app, on a real screenshot.
struct GuideStep: Hashable {
    /// Asset name by feature and iOS version, e.g. "widgetHome_ios27_step1".
    let asset: String
    /// One short sentence.
    let sentence: String
    /// Where to tap, as a fraction of the screenshot, measured at capture.
    var tap: UnitPoint?
}

/// The setup guides. Screenshots are from the iOS 27 simulator
/// (design/screenshots/guide, captured by scripts/capture-guides.sh).
/// The Action Button guide comes back once it's recorded on a real iPhone.
enum GuidePath: String, Identifiable, CaseIterable {
    case homeScreen, lockScreen, controlCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .homeScreen: "Home Screen widget"
        case .lockScreen: "Lock Screen widget"
        case .controlCenter: "Control Center"
        }
    }

    /// The finished screen, for "You're set." and onboarding's preview.
    var doneAsset: String {
        switch self {
        case .homeScreen: "widgetHome_ios27_done"
        case .lockScreen: "widgetLock_ios27_done"
        case .controlCenter: "controlCenter_ios27_done"
        }
    }

    var doneSentence: String {
        switch self {
        case .homeScreen: "Tap Log on your Home Screen whenever it itches. The app never opens."
        case .lockScreen: "Log an itch or see last night without unlocking."
        case .controlCenter: "Swipe down and tap the hand to log an itch."
        }
    }

    var steps: [GuideStep] {
        switch self {
        case .homeScreen: [
            GuideStep(asset: "widgetHome_ios27_step1", sentence: "Touch and hold an empty area of your Home Screen until the apps jiggle.", tap: UnitPoint(x: 0.500, y: 0.680)),
            GuideStep(asset: "widgetHome_ios27_step2", sentence: "Tap Edit in the top-left corner.", tap: UnitPoint(x: 0.172, y: 0.038)),
            GuideStep(asset: "widgetHome_ios27_step3", sentence: "Tap Add Widget.", tap: UnitPoint(x: 0.393, y: 0.106)),
            GuideStep(asset: "widgetHome_ios27_step4", sentence: "Search for Cali Care and tap it.", tap: UnitPoint(x: 0.500, y: 0.291)),
            GuideStep(asset: "widgetHome_ios27_step5", sentence: "Swipe to pick a size, then tap Add Widget.", tap: UnitPoint(x: 0.500, y: 0.905)),
            GuideStep(asset: "widgetHome_ios27_step6", sentence: "Tap the checkmark in the top-right corner.", tap: UnitPoint(x: 0.828, y: 0.038)),
        ]
        case .lockScreen: [
            GuideStep(asset: "widgetLock_ios27_step1", sentence: "Touch and hold your Lock Screen.", tap: UnitPoint(x: 0.500, y: 0.450)),
            GuideStep(asset: "widgetLock_ios27_step2", sentence: "Tap Customize.", tap: UnitPoint(x: 0.500, y: 0.930)),
            GuideStep(asset: "widgetLock_ios27_step3", sentence: "Tap Add Widgets under the clock.", tap: UnitPoint(x: 0.500, y: 0.788)),
            GuideStep(asset: "widgetLock_ios27_step4", sentence: "Tap Cali Care in the list.", tap: UnitPoint(x: 0.500, y: 0.724)),
            GuideStep(asset: "widgetLock_ios27_step5", sentence: "Tap Log to add it. Swipe for Last night.", tap: UnitPoint(x: 0.500, y: 0.710)),
            GuideStep(asset: "widgetLock_ios27_step6", sentence: "Tap Done.", tap: UnitPoint(x: 0.818, y: 0.038)),
        ]
        case .controlCenter: [
            GuideStep(asset: "controlCenter_ios27_step1", sentence: "Swipe down from the top-right corner.", tap: UnitPoint(x: 0.900, y: 0.010)),
            GuideStep(asset: "controlCenter_ios27_step2", sentence: "Touch and hold an empty area.", tap: UnitPoint(x: 0.500, y: 0.880)),
            GuideStep(asset: "controlCenter_ios27_step3", sentence: "Tap Add a Control.", tap: UnitPoint(x: 0.500, y: 0.916)),
            GuideStep(asset: "controlCenter_ios27_step4", sentence: "Search for Cali Care, then tap Log.", tap: UnitPoint(x: 0.144, y: 0.302)),
            GuideStep(asset: "controlCenter_ios27_step5", sentence: "Tap an empty area to finish."),
        ]
        }
    }
}

/// A guide, one step per screen: the real screenshot with the spot ringed, a
/// zoomed circle of that spot, one sentence, Back and Next, then "You're set."
struct SetupGuide: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let path: GuidePath
    @State private var index = 0
    @State private var forward = true

    private var steps: [GuideStep] { path.steps }
    private var isDone: Bool { index == steps.count }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                if isDone {
                    page(asset: path.doneAsset, tap: nil, heading: "You’re set.", sentence: path.doneSentence)
                } else {
                    page(asset: steps[index].asset, tap: steps[index].tap, heading: nil, sentence: steps[index].sentence)
                }
            }
            .id(index)
            .transition(transition)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(swipe)
            footer
        }
        .paperBackground()
    }

    private var topBar: some View {
        VStack(spacing: Spacing.x4) {
            HStack {
                Text(path.title)
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .frame(width: Size.touchTarget, height: Size.touchTarget)
                }
                .accessibilityLabel("Close")
            }
            HStack(spacing: Spacing.x1) {
                ForEach(0...steps.count, id: \.self) { item in
                    Capsule()
                        .fill(item <= index ? palette.accent : palette.hairline)
                        .frame(height: 2)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(isDone ? "Finished" : "Step \(index + 1) of \(steps.count)")
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.x2)
    }

    private func page(asset: String, tap: UnitPoint?, heading: String?, sentence: String) -> some View {
        VStack(spacing: Spacing.x4) {
            if let heading {
                Text(heading)
                    .textStyle(.title)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            GuideScreenshot(asset: asset, tap: tap)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
            Text(sentence)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.x5)
    }

    private var footer: some View {
        HStack(spacing: Spacing.x4) {
            if index > 0 {
                Button("Back") { go(to: index - 1) }
                    .buttonStyle(.textLink)
            }
            Button(isDone ? "Done" : "Next") {
                if isDone { dismiss() } else { go(to: index + 1) }
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.x4)
        .padding(.bottom, Spacing.x2)
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        )
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            if value.translation.width < -40 { go(to: index + 1) }
            if value.translation.width > 40 { go(to: index - 1) }
        }
    }

    private func go(to next: Int) {
        guard (0...steps.count).contains(next), next != index else { return }
        forward = next > index
        withAnimation(.easeOut(duration: 0.25)) { index = next }
    }
}

/// A real screenshot in a rounded phone shape, with the tap spot ringed and a
/// zoomed circle of that spot beside it.
struct GuideScreenshot: View {
    @Environment(\.palette) private var palette
    let asset: String
    let tap: UnitPoint?

    /// The captures are 402 × 874 points.
    private let aspect: CGFloat = 402.0 / 874.0
    private let calloutSize: CGFloat = 112
    private let zoom: CGFloat = 2.4

    var body: some View {
        GeometryReader { proxy in
            let height = min(proxy.size.height, proxy.size.width / aspect)
            let size = CGSize(width: height * aspect, height: height)
            ZStack(alignment: .topLeading) {
                shot(size)
                    .clipShape(RoundedRectangle(cornerRadius: size.width * 0.11))
                    .overlay(RoundedRectangle(cornerRadius: size.width * 0.11).strokeBorder(palette.hairline, lineWidth: 1))
                if let tap {
                    TapRing()
                        .position(x: tap.x * size.width, y: max(tap.y * size.height, 16))
                    callout(tap, size)
                }
            }
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func shot(_ size: CGSize) -> some View {
        Image(asset)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
    }

    /// Sits over the phone's edge on the side away from the tap, at the tap's
    /// height, reaching only a little past the phone so it stays on screen.
    private func callout(_ tap: UnitPoint, _ size: CGSize) -> some View {
        let big = CGSize(width: size.width * zoom, height: size.height * zoom)
        let half = calloutSize / 2
        let x = tap.x < 0.5 ? size.width - half * 0.55 : half * 0.55
        // A tap near the middle would sit under the circle: move it up or down instead.
        let central = abs(tap.x - 0.5) < 0.2
        let shift = central ? (tap.y > 0.5 ? -calloutSize * 1.1 : calloutSize * 1.1) : 0
        let y = min(max(tap.y * size.height + shift, half), size.height - half)
        return shot(big)
            .offset(x: (0.5 - tap.x) * big.width, y: (0.5 - tap.y) * big.height)
            .frame(width: calloutSize, height: calloutSize)
            .clipShape(Circle())
            .overlay(TapRing())
            .overlay(Circle().strokeBorder(palette.paper, lineWidth: 3))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .position(x: x, y: y)
    }
}

/// The accent ring and dot that mark where to tap.
private struct TapRing: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle().strokeBorder(palette.accent, lineWidth: 3).frame(width: 40, height: 40)
            Circle().fill(palette.accent.opacity(0.85)).frame(width: 12, height: 12)
        }
    }
}

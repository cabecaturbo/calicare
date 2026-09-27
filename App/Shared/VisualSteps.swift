import Core
import SwiftUI
import UIKit

/// One step of something that happens outside the app, shown on a real screenshot.
struct VisualStep: Identifiable, Hashable {
    /// Asset catalog name, by feature and iOS version, e.g. "widgetHome_ios27_step1".
    let asset: String
    /// One short sentence: "Touch and hold an empty spot on your Home Screen."
    let sentence: String
    /// Where to tap, as a fraction of the screenshot's width and height.
    var tap: UnitPoint?

    var id: String { asset }
}

/// Swipeable steps, one per screen: an iPhone frame with the exact screen, the
/// spot to tap ringed in indigo, and one sentence under it. "Show me again"
/// goes back to the start. The host supplies Done and Skip.
struct VisualSteps: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let steps: [VisualStep]
    @State private var index = 0
    @State private var forward = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            StepPage(step: steps[index], number: index + 1, count: steps.count)
                .id(index)
                .transition(transition)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(swipe)
                .accessibilityElement(children: .combine)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: go(to: index + 1)
                    case .decrement: go(to: index - 1)
                    @unknown default: break
                    }
                }
                .accessibilityHint("Swipe up or down to change steps.")

            HStack(spacing: Spacing.x4) {
                if index > 0 {
                    Button("Back") { go(to: index - 1) }
                        .buttonStyle(.textLink)
                }
                Spacer(minLength: 0)
                if index < steps.count - 1 {
                    Button("Next step") { go(to: index + 1) }
                        .buttonStyle(.textLink)
                } else if steps.count > 1 {
                    Button("Show me again") { go(to: 0) }
                        .buttonStyle(.textLink)
                }
            }
            .padding(.horizontal, Spacing.margin)
        }
        .clipped()
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
        guard steps.indices.contains(next), next != index else { return }
        forward = next > index
        withAnimation(.easeOut(duration: 0.25)) { index = next }
    }
}

private struct StepPage: View {
    @Environment(\.palette) private var palette
    let step: VisualStep
    let number: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                Text("Step \(number) of \(count)")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
                Text(step.sentence)
                    .textStyle(.body)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.margin)
            PhoneFrame(step: step)
                .frame(maxWidth: .infinity)
        }
    }
}

/// A plain ink bezel around the screenshot. The screenshot is the real screen;
/// only the frame is drawn.
private struct PhoneFrame: View {
    @Environment(\.palette) private var palette
    let step: VisualStep

    /// iPhone 17 screen, 402 × 874 points.
    private static let aspect: CGFloat = 402.0 / 874.0
    /// Short enough that the sentence, the whole phone, and the buttons fit on one screen.
    private static let height: CGFloat = 340
    private static let bezel: CGFloat = 5

    var body: some View {
        let screenWidth = Self.height * Self.aspect
        ZStack {
            if let image = UIImage(named: step.asset) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibilityHidden(true)
            } else {
                placeholder
            }
            if let tap = step.tap {
                TapRing()
                    .position(x: tap.x * screenWidth, y: tap.y * Self.height)
            }
        }
        .frame(width: screenWidth, height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(Self.bezel)
        .background(palette.ink, in: RoundedRectangle(cornerRadius: 30 + Self.bezel, style: .continuous))
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Screen recording to come")
                .textStyle(.control)
                .foregroundStyle(palette.ink)
            Text(step.sentence)
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
        }
        .padding(Spacing.x4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.oat)
    }
}

/// The spot to tap: a soft indigo ring. No glow, no pulse.
private struct TapRing: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Circle()
            .fill(palette.indigo.opacity(0.15))
            .overlay(Circle().strokeBorder(palette.indigo, lineWidth: 2.5))
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }
}

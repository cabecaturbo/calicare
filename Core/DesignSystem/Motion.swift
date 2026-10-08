import SwiftUI
import UIKit

/// The one motion system (DESIGN.md §8). Every animation in the app uses
/// these tokens and modifiers; nothing else picks a duration or a curve.
/// Three speeds, one curve, five moves (Press, Done, Arrive, Move, and the
/// system's own sheets and navigation). Night (8 PM to 7 AM) is 1.3× slower.
/// Reduce Motion turns every move into a crossfade with the same meaning.
public enum Motion {
    public enum Speed: Sendable, CaseIterable {
        /// Press, small state changes: 0.2s.
        case quick
        /// Done, banners, switching what's shown: 0.35s.
        case standard
        /// Arrive, drawings: 0.6s.
        case gentle

        public var seconds: Double {
            switch self {
            case .quick: 0.2
            case .standard: 0.35
            case .gentle: 0.6
            }
        }
    }

    /// Night slows every move down a little.
    public static let nightFactor = 1.3
    /// The one curve: a soft start and a long, calm settle. No bounce, no overshoot.
    public static let curve: (x1: Double, y1: Double, x2: Double, y2: Double) = (0.3, 0, 0.2, 1)
    /// Press: how far a pressed control shrinks.
    public static let pressScale: CGFloat = 0.96
    /// Arrive: how far an item rises as it fades in.
    public static let riseOffset: CGFloat = 8
    /// Arrive: the gap between items, and the most items that wait their turn.
    public static let stagger: Double = 0.06
    public static let maxStagger = 6

    public static func duration(_ speed: Speed, night: Bool) -> Double {
        speed.seconds * (night ? nightFactor : 1)
    }

    /// The only Animation the app makes.
    public static func animation(_ speed: Speed, night: Bool, delay: Double = 0) -> Animation {
        Animation.timingCurve(curve.x1, curve.y1, curve.x2, curve.y2, duration: duration(speed, night: night)).delay(delay)
    }

    /// Arrive's wait for the item at `index`: 60ms each, capped at six.
    public static func delay(index: Int) -> Double {
        Double(min(max(index, 0), maxStagger)) * stagger
    }

    /// Reduce Motion: no shrinking, no rising; the fade carries the meaning.
    public static func pressScale(reduceMotion: Bool) -> CGFloat { reduceMotion ? 1 : pressScale }
    public static func riseOffset(reduceMotion: Bool) -> CGFloat { reduceMotion ? 0 : riseOffset }

    /// Something arriving or leaving (banners, a line that appears): fade and
    /// rise, or a crossfade with Reduce Motion.
    public static func arriveTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: riseOffset))
    }

    /// A plain crossfade: a line or picture swapping in place.
    public static var fade: AnyTransition { .opacity }

    /// Widgets' "Logged" confirmation: an opacity change only (the system times it).
    public static var loggedTransition: AnyTransition { fade }

    /// Moving between steps (onboarding, guides): slide from the side, or a crossfade.
    public static func stepTransition(forward: Bool, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .opacity)
    }

    /// Progress's bars rise only the first time it opens each day.
    public static func shouldArrive(lastShown: String?, now: Date, calendar: Calendar = .current) -> Bool {
        lastShown != dayKey(now, calendar: calendar)
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    // MARK: - Haptics

    public enum Haptic: Sendable {
        /// Done: something was logged or checked off. One light tap.
        case done
        /// Picking among choices.
        case select
    }

    /// The single haptic helper, for code outside a view's feedback.
    @MainActor
    public static func haptic(_ kind: Haptic) {
        switch kind {
        case .done: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .select: UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    static func feedback(_ kind: Haptic) -> SensoryFeedback {
        switch kind {
        case .done: .impact(weight: .light)
        case .select: .selection
        }
    }
}

/// The only `withAnimation`: animates a state change at one of the three speeds.
@MainActor
public func withMotion<Result>(_ speed: Motion.Speed, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.animation(speed, night: NightMode.isLayoutActive()), body)
}

extension Binding {
    /// A binding whose changes animate at one of the three speeds.
    @MainActor
    public func motion(_ speed: Motion.Speed) -> Binding<Value> {
        animation(Motion.animation(speed, night: NightMode.isLayoutActive()))
    }
}

// MARK: - Modifiers

extension View {
    /// The only `.animation(_:value:)`: animate changes to `value` at a speed.
    /// `staggerIndex` waits 60ms per earlier item (at most six), like Arrive.
    public func motion<V: Equatable>(_ speed: Motion.Speed, value: V, staggerIndex: Int = 0) -> some View {
        modifier(MotionValueModifier(speed: speed, value: value, staggerIndex: staggerIndex))
    }

    /// Press, for a control that knows when it's held (button styles).
    public func pressable(_ isPressed: Bool) -> some View {
        modifier(PressModifier(isPressed: isPressed))
    }

    /// Press, for any tappable view: shrinks a little while a finger is down.
    public func pressable() -> some View {
        modifier(TouchPressModifier())
    }

    /// Done: animates the change at the standard speed and gives one light
    /// tap when it becomes done. Pair with `DoneMark` for the circle and check.
    public func doneMark(isDone: Bool) -> some View {
        modifier(DoneModifier(isDone: isDone))
    }

    /// Done's haptic for a moment with no mark (a log from a button): one
    /// light tap each time `trigger` changes to a new non-nil value.
    public func doneFeedback<T: Equatable>(trigger: T?) -> some View {
        sensoryFeedback(Motion.feedback(.done), trigger: trigger) { _, new in new != nil }
    }

    /// A light selection tap when `trigger` changes (pickers, choices).
    public func selectFeedback<T: Equatable>(trigger: T) -> some View {
        sensoryFeedback(Motion.feedback(.select), trigger: trigger)
    }

    /// Arrive: fade in and rise 8pt, gentle, waiting 60ms per earlier item
    /// (at most six). Runs once when the view first appears; `enabled: false`
    /// shows it in place with no motion.
    public func arrive(index: Int, enabled: Bool = true) -> some View {
        modifier(ArriveModifier(index: index, enabled: enabled))
    }
}

private struct MotionValueModifier<V: Equatable>: ViewModifier {
    @Environment(\.nightLayout) private var night
    let speed: Motion.Speed
    let value: V
    let staggerIndex: Int

    func body(content: Content) -> some View {
        content.animation(Motion.animation(speed, night: night, delay: Motion.delay(index: staggerIndex)), value: value)
    }
}

private struct PressModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? Motion.pressScale(reduceMotion: reduceMotion) : 1)
            .opacity(isPressed && reduceMotion ? 0.7 : 1)
            .motion(.quick, value: isPressed)
    }
}

private struct TouchPressModifier: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .pressable(isPressed)
            .simultaneousGesture(DragGesture(minimumDistance: 0).updating($isPressed) { _, state, _ in state = true })
    }
}

private struct DoneModifier: ViewModifier {
    let isDone: Bool

    func body(content: Content) -> some View {
        content
            .motion(.standard, value: isDone)
            .sensoryFeedback(Motion.feedback(.done), trigger: isDone) { old, new in !old && new }
    }
}

private struct ArriveModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.nightLayout) private var night
    let index: Int
    let enabled: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        let visible = shown || !enabled
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : Motion.riseOffset(reduceMotion: reduceMotion))
            .onAppear {
                guard enabled, !shown else { return }
                withAnimation(Motion.animation(.gentle, night: night, delay: Motion.delay(index: index))) { shown = true }
            }
    }
}

/// Press for a plain button: looks like `.plain`, shrinks a little while held.
public struct PressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.pressable(configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    public static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// Done's mark: the circle fills and the check draws itself. `ring` is the
/// empty circle's outline; Reduce Motion crossfades the check instead.
public struct DoneMark: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isDone: Bool
    var size: CGFloat = 28
    var ring: Color?
    var ringWidth: CGFloat = 1.5
    var fill: Color?

    public init(isDone: Bool, size: CGFloat = 28, ring: Color? = nil, ringWidth: CGFloat = 1.5, fill: Color? = nil) {
        self.isDone = isDone
        self.size = size
        self.ring = ring
        self.ringWidth = ringWidth
        self.fill = fill
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(isDone ? palette.accent : (fill ?? palette.paper))
            Circle()
                .strokeBorder(ring ?? palette.ink, lineWidth: ringWidth)
                .opacity(isDone ? 0 : 1)
            CheckShape()
                .trim(from: 0, to: isDone || reduceMotion ? 1 : 0)
                .stroke(palette.paper, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.42, height: size * 0.32)
                .opacity(isDone ? 1 : 0)
        }
        .frame(width: size, height: size)
        .doneMark(isDone: isDone)
        .accessibilityHidden(true)
    }
}

/// A check, drawn left to right so `trim` draws it like a pen.
private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

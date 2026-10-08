import Core
import SwiftUI

/// Hand-drawn ink line drawings (DESIGN.md §6), one set per screen: Today's
/// sun and moon, Plan's sprout (morning) and lamp (evening), Progress's
/// flower (week) and tree (month).
/// They draw themselves in (about a second) every time the screen appears or
/// the app comes back, then stop; they never loop. With Reduce Motion they
/// appear complete.
struct Illustration: View {
    enum Kind { case sun, moon, flower, sprout, lamp, tree }

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let kind: Kind
    var size = CGSize(width: 84, height: 80)
    @State private var drawn: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(Array(strokes.enumerated()), id: \.offset) { index, stroke in
                stroke
                    .trim(from: 0, to: reduceMotion ? 1 : drawn)
                    .stroke(palette.ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .motion(.gentle, value: drawn, staggerIndex: index)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
        .onAppear { replay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { replay() }
        }
    }

    /// Wipes the drawing without animating, then draws it in again.
    private func replay() {
        guard !reduceMotion else { drawn = 1; return }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { drawn = 0 }
        Task { @MainActor in drawn = 1 }
    }

    private var strokes: [InkPath] {
        switch kind {
        case .sun: [InkPath(.sunDisc), InkPath(.sunRays), InkPath(.horizon)]
        case .moon: [InkPath(.moon), InkPath(.stars)]
        case .flower: [InkPath(.stem), InkPath(.petals), InkPath(.ground)]
        case .sprout: [InkPath(.soil), InkPath(.sproutStem), InkPath(.leaves)]
        case .lamp: [InkPath(.lampBase), InkPath(.lampShade), InkPath(.glow)]
        case .tree: [InkPath(.ground), InkPath(.trunk), InkPath(.canopy)]
        }
    }
}

/// One hand-drawn stroke, drawn in a 100 × 92 box and scaled to fit.
struct InkPath: Shape {
    enum Drawing {
        case sunDisc, sunRays, horizon, moon, stars, stem, petals, ground
        case soil, sproutStem, leaves, lampBase, lampShade, glow, trunk, canopy
    }
    let drawing: Drawing

    init(_ drawing: Drawing) { self.drawing = drawing }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch drawing {
        case .sunDisc:
            p.move(to: pt(50, 30))
            p.addCurve(to: pt(66, 47), control1: pt(60, 29), control2: pt(67, 37))
            p.addCurve(to: pt(48, 61), control1: pt(65, 56), control2: pt(57, 62))
            p.addCurve(to: pt(34, 44), control1: pt(39, 60), control2: pt(33, 53))
            p.addCurve(to: pt(50, 30), control1: pt(35, 36), control2: pt(41, 31))
        case .sunRays:
            let rays: [(Double, Double, Double, Double)] = [(50, 18, 50, 10), (69, 26, 75, 20), (78, 46, 86, 45), (31, 26, 25, 21), (22, 47, 14, 46)]
            for r in rays {
                p.move(to: pt(r.0, r.1)); p.addLine(to: pt(r.2, r.3))
            }
        case .horizon:
            p.move(to: pt(6, 76))
            p.addCurve(to: pt(56, 75), control1: pt(24, 72), control2: pt(40, 78))
            p.addCurve(to: pt(96, 74), control1: pt(70, 72), control2: pt(84, 77))
        case .moon:
            p.move(to: pt(62, 18))
            p.addCurve(to: pt(42, 46), control1: pt(48, 20), control2: pt(40, 32))
            p.addCurve(to: pt(70, 64), control1: pt(44, 60), control2: pt(57, 68))
            p.addCurve(to: pt(51, 42), control1: pt(60, 62), control2: pt(52, 54))
            p.addCurve(to: pt(62, 18), control1: pt(50, 31), control2: pt(55, 22))
        case .stars:
            for (x, y, r) in [(22.0, 26.0, 4.0), (84, 43, 3), (28, 65, 2.5)] {
                p.move(to: pt(x, y - r)); p.addLine(to: pt(x, y + r))
                p.move(to: pt(x - r, y)); p.addLine(to: pt(x + r, y))
            }
        case .stem:
            p.move(to: pt(50, 86))
            p.addCurve(to: pt(50, 46), control1: pt(49, 72), control2: pt(52, 60))
        case .petals:
            let c = pt(50, 42)
            // Each petal: out through one control point to the tip, back through the other.
            let petals: [(Double, Double, Double, Double, Double, Double)] = [
                (44, 32, 56, 32, 50, 22), (60, 36, 60, 48, 69, 42), (56, 52, 44, 52, 49, 61), (40, 48, 40, 36, 31, 42),
            ]
            for q in petals {
                p.move(to: c)
                p.addCurve(to: pt(q.4, q.5), control1: pt(q.0, q.1), control2: pt(q.4, q.5))
                p.addCurve(to: c, control1: pt(q.4, q.5), control2: pt(q.2, q.3))
            }
        case .ground:
            p.move(to: pt(18, 88))
            p.addCurve(to: pt(82, 86), control1: pt(34, 85), control2: pt(58, 90))
        case .soil:
            p.move(to: pt(20, 80))
            p.addCurve(to: pt(80, 79), control1: pt(36, 76), control2: pt(62, 83))
        case .sproutStem:
            p.move(to: pt(50, 79))
            p.addCurve(to: pt(51, 44), control1: pt(48, 66), control2: pt(53, 56))
        case .leaves:
            // Left leaf, then right leaf: out along one edge, back along the other.
            p.move(to: pt(50, 60))
            p.addCurve(to: pt(28, 46), control1: pt(44, 50), control2: pt(35, 44))
            p.addCurve(to: pt(50, 60), control1: pt(30, 55), control2: pt(40, 60))
            p.move(to: pt(51, 50))
            p.addCurve(to: pt(74, 32), control1: pt(56, 38), control2: pt(66, 31))
            p.addCurve(to: pt(51, 50), control1: pt(74, 42), control2: pt(63, 50))
        case .lampBase:
            p.move(to: pt(50, 46))
            p.addCurve(to: pt(50, 76), control1: pt(49, 56), control2: pt(51, 66))
            p.move(to: pt(36, 80))
            p.addCurve(to: pt(64, 80), control1: pt(40, 74), control2: pt(60, 74))
            p.addLine(to: pt(36, 80))
        case .lampShade:
            p.move(to: pt(33, 46))
            p.addLine(to: pt(40, 20))
            p.addCurve(to: pt(60, 20), control1: pt(46, 18), control2: pt(54, 18))
            p.addLine(to: pt(67, 46))
            p.addCurve(to: pt(33, 46), control1: pt(56, 49), control2: pt(44, 49))
        case .glow:
            for r in [(26.0, 50.0, 18.0, 56.0), (74, 50, 82, 56), (24, 34, 15, 33), (76, 34, 85, 33)] {
                p.move(to: pt(r.0, r.1)); p.addLine(to: pt(r.2, r.3))
            }
        case .trunk:
            p.move(to: pt(50, 87))
            p.addCurve(to: pt(50, 52), control1: pt(48, 76), control2: pt(52, 62))
            p.move(to: pt(50, 66))
            p.addCurve(to: pt(61, 56), control1: pt(54, 62), control2: pt(58, 58))
        case .canopy:
            // A soft cloud of leaves: five bumps around the top of the trunk.
            p.move(to: pt(30, 50))
            p.addCurve(to: pt(32, 28), control1: pt(20, 44), control2: pt(22, 30))
            p.addCurve(to: pt(52, 14), control1: pt(34, 16), control2: pt(46, 12))
            p.addCurve(to: pt(72, 26), control1: pt(62, 12), control2: pt(72, 18))
            p.addCurve(to: pt(72, 50), control1: pt(82, 32), control2: pt(82, 46))
            p.addCurve(to: pt(30, 50), control1: pt(60, 58), control2: pt(42, 58))
        }
        let scale = min(rect.width / 100, rect.height / 92)
        return p.applying(CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: (rect.width / scale - 100) / 2, y: (rect.height / scale - 92) / 2))
    }

    private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
}

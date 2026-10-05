import Core
import SwiftUI
import WidgetKit

/// The main log button: a terracotta tile with a soft top-to-bottom shade,
/// the palm in a pale circle, and "Log" in the serif. In tinted and clear
/// looks it keeps a filled glass shape, so it stays the widget's main thing.
struct ItchyTile: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let child: ChildEntity?
    let palette: Palette

    var body: some View {
        let fullColor = renderingMode == .fullColor
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(intent: WidgetLogIntent(action: .itchy, child: child)) {
            VStack(spacing: Spacing.x2) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill((fullColor ? palette.paper : Color.primary).opacity(0.18)))
                Text("Log")
                    .font(.custom("NewsreaderDisplay-Medium", size: 20, relativeTo: .title3))
            }
            .foregroundStyle(fullColor ? palette.paper : Color.primary)
            .widgetAccentable()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: Size.touchTarget)
            .background {
                if fullColor {
                    shape.fill(LinearGradient(
                        colors: [palette.accent.mix(with: .white, by: 0.08), palette.accent.mix(with: .black, by: 0.06)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                } else {
                    shape.fill(Color.primary.opacity(0.28))
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WidgetAction.itchy.accessibilityLabel(for: child?.name))
    }
}

/// A quieter one-tap button beside Log: a soft oat pill with a small
/// terracotta icon in full color, an outline in tinted and clear.
struct SecondaryWidgetButton: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let palette: Palette
    let title: String
    let symbol: String

    var body: some View {
        let fullColor = renderingMode == .fullColor
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: Spacing.x1 + 2) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(fullColor ? palette.accent : Color.primary)
                .widgetAccentable()
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(fullColor ? palette.ink : Color.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: Size.touchTarget)
        .background {
            if fullColor {
                shape.fill(palette.oat)
            } else {
                shape.strokeBorder(Color.primary.opacity(0.5), lineWidth: 1)
            }
        }
        .contentShape(shape)
    }
}

/// Flare logs instantly; Note opens the app's note sheet (there's no typing in a widget).
struct FlareButton: View {
    let child: ChildEntity?
    let palette: Palette

    var body: some View {
        Button(intent: WidgetLogIntent(action: .flare, child: child)) {
            SecondaryWidgetButton(palette: palette, title: "Flare", symbol: "flame")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WidgetAction.flare.accessibilityLabel(for: child?.name))
    }
}

struct NoteLink: View {
    let palette: Palette

    var body: some View {
        Link(destination: DeepLink.note) {
            SecondaryWidgetButton(palette: palette, title: "Note", symbol: "square.and.pencil")
        }
        .accessibilityLabel("Write a note")
        .accessibilityHint("Opens Cali Care.")
    }
}

/// Undoes the most recent log from the last 10 minutes.
struct UndoButton: View {
    let palette: Palette

    var body: some View {
        Button(intent: UndoLastIntent()) {
            Text("Undo")
                .font(TypeStyle.control.font)
                .foregroundStyle(palette.accent)
                .frame(minWidth: Size.touchTarget, minHeight: Size.touchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Removes what you just logged.")
    }
}

/// "Logged" and what was logged, in words.
struct LoggedLabel: View {
    let feedback: WidgetFeedback
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.accent)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text("Logged")
                .font(TypeStyle.title.font)
                .foregroundStyle(palette.ink)
            Text("\(feedback.title), \(feedback.loggedAt.formatted(date: .omitted, time: .shortened))")
                .font(TypeStyle.meta.font)
                .foregroundStyle(palette.graphite)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shown before any child is added. Tapping opens the app.
struct AddChildPrompt: View {
    let palette: Palette

    var body: some View {
        Text("Add your child in Cali Care to start logging.")
            .font(TypeStyle.body.font)
            .foregroundStyle(palette.graphite)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A 0.5pt rule for widget ledgers.
struct WidgetRule: View {
    let palette: Palette
    var vertical = false

    var body: some View {
        palette.hairline
            .frame(width: vertical ? Rule.width : nil, height: vertical ? nil : Rule.width)
    }
}

extension WidgetAction {
    var shortTitle: String {
        switch self {
        case .itchy: "Itchy"
        case .roughNight: "Rough night"
        case .bowelMovement: "Bowel movement"
        case .routineDone: "Routine done"
        case .flare: "Flare"
        }
    }

    func accessibilityLabel(for childName: String?) -> String {
        let what = switch self {
        case .itchy: "Log itching"
        case .roughNight: "Log a rough night"
        case .bowelMovement: "Log a bowel movement"
        case .routineDone: "Log routine done"
        case .flare: "Log a flare"
        }
        guard let childName else { return what }
        return "\(what) for \(childName)"
    }
}

enum WidgetText {
    /// "Last: 1:52 AM", "Last: Tue 1:52 AM by Dad", or a calm empty state.
    static func last(_ date: Date?, by byline: String? = nil, now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        guard date != nil else { return "No itches logged yet" }
        return lastItch(date, by: byline, now: now, calendar: calendar).replacingOccurrences(of: "Last itch ", with: "Last: ")
    }

    /// "Last night: 2 wake-ups" by day, "Tonight: 1 wake-up" from 7 PM.
    static func wakeUps(_ count: Int, isNight: Bool) -> String {
        let noun = count == 1 ? "wake-up" : "wake-ups"
        return "\(isNight ? "Tonight" : "Last night"): \(count) \(noun)"
    }

    /// "Last itch 2:14 AM", "Last itch Tue 2:14 AM by Dad", or a calm empty state.
    static func lastItch(_ date: Date?, by byline: String? = nil, now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        guard let date else { return "No itches logged yet" }
        let when: String
        if calendar.isDate(date, inSameDayAs: now) {
            when = date.formatted(date: .omitted, time: .shortened)
        } else if now.timeIntervalSince(date) < 6 * 24 * 3600 {
            when = date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        } else {
            when = date.formatted(.dateTime.month(.abbreviated).day())
        }
        return ["Last itch \(when)", byline].compactMap { $0 }.joined(separator: " ")
    }

    static func night(_ rating: NightRating?) -> String {
        switch rating {
        case .good?: "Good night"
        case .okay?: "Okay night"
        case .rough?: "Rough night"
        case nil: "Not rated yet"
        }
    }
}

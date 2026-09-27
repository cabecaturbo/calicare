import Core
import SwiftUI
import WidgetKit

/// A widget cell that logs instantly, without opening the app: a word, and a
/// count or time in meta. No icons, no tile fill.
struct LogButton: View {
    let action: WidgetAction
    let child: ChildEntity?
    let detail: String?
    let palette: Palette
    /// The small widget's one big word, or a medium widget ledger cell.
    var prominent = false

    var body: some View {
        Button(intent: WidgetLogIntent(action: action, child: child)) {
            VStack(alignment: .leading, spacing: prominent ? Spacing.x1 : 2) {
                if prominent { Spacer(minLength: 0) }
                Text(action.shortTitle)
                    .font(prominent ? TypeStyle.display.font : TypeStyle.control.font)
                    .foregroundStyle(palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let detail {
                    Text(detail)
                        .font(TypeStyle.meta.font)
                        .foregroundStyle(palette.graphite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .frame(minWidth: Size.touchTarget, minHeight: Size.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel(for: child?.name))
        .accessibilityValue(detail ?? "")
    }
}

/// Undoes the most recent log from the last 10 minutes.
struct UndoButton: View {
    let palette: Palette

    var body: some View {
        Button(intent: UndoLastIntent()) {
            Text("Undo")
                .font(TypeStyle.control.font)
                .foregroundStyle(palette.indigo)
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
        Text("Add your child in CaliCare to start logging.")
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
        }
    }

    func accessibilityLabel(for childName: String?) -> String {
        let what = switch self {
        case .itchy: "Log itching"
        case .roughNight: "Log a rough night"
        case .bowelMovement: "Log a bowel movement"
        case .routineDone: "Log routine done"
        }
        guard let childName else { return what }
        return "\(what) for \(childName)"
    }
}

enum WidgetText {
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

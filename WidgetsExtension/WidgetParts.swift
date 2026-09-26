import Core
import SwiftUI
import WidgetKit

/// A widget button that logs instantly, without opening the app.
struct LogButton: View {
    let action: WidgetAction
    let child: ChildEntity?
    let detail: String?
    let palette: Palette
    /// Big filled sage button (small widget) or a quiet sand tile (medium widget).
    var prominent = false

    var body: some View {
        Button(intent: WidgetLogIntent(action: action, child: child)) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: action.symbol)
                    .font(.system(size: prominent ? 30 : 20, weight: .medium))
                    .foregroundStyle(prominent ? palette.onAccent : palette.accent)
                Text(action.shortTitle)
                    .font(prominent ? Typography.title3 : Typography.caption)
                    .foregroundStyle(prominent ? palette.onAccent : palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let detail {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(prominent ? palette.onAccent : palette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(Spacing.xxs)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: TouchTarget.minimum, minHeight: TouchTarget.minimum)
            .background(
                prominent ? palette.accent : palette.sand,
                in: RoundedRectangle(cornerRadius: prominent ? Radius.card : Radius.small, style: .continuous)
            )
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
            Label("Undo", systemImage: "arrow.uturn.backward")
                .font(Typography.button)
                .foregroundStyle(palette.sageDark)
                .padding(.horizontal, Spacing.m)
                .frame(minWidth: TouchTarget.minimum, minHeight: TouchTarget.minimum)
                .background(palette.sand, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Undo")
        .accessibilityHint("Removes what you just logged.")
    }
}

/// Calm check mark and what was logged.
struct LoggedLabel: View {
    let feedback: WidgetFeedback
    let palette: Palette

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text("Logged")
                    .font(Typography.headline)
                    .foregroundStyle(palette.ink)
                Text("\(feedback.title), \(feedback.loggedAt.formatted(date: .omitted, time: .shortened))")
                    .font(Typography.caption)
                    .foregroundStyle(palette.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shown before any child is added. Tapping opens the app.
struct AddChildPrompt: View {
    let palette: Palette

    var body: some View {
        Text("Add your child in CaliCare to start logging.")
            .font(Typography.callout)
            .foregroundStyle(palette.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    var symbol: String {
        switch self {
        case .itchy: "hand.raised"
        case .roughNight: "moon.zzz"
        case .bowelMovement: "toilet"
        case .routineDone: "checkmark.circle"
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
    /// "Last itch 2:14 AM", "Last itch Tue 2:14 AM", or a calm empty state.
    static func lastItch(_ date: Date?, now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        guard let date else { return "No itches logged yet" }
        if calendar.isDate(date, inSameDayAs: now) {
            return "Last itch \(date.formatted(date: .omitted, time: .shortened))"
        }
        if now.timeIntervalSince(date) < 6 * 24 * 3600 {
            return "Last itch \(date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
        }
        return "Last itch \(date.formatted(.dateTime.month(.abbreviated).day()))"
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

import Core
import SwiftUI

/// Plan's Supplements: only what the plan lists, with its dose and schedule.
/// "Start" when you're ready (the plan's spacing rules give "Can start after"),
/// then a tap each time it's taken. The plan's rules sit underneath.
struct SupplementsSection: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let plan: SupplementPlan
    @State private var stopping: SupplementPlan.Row?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Supplements")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(plan.rows) { row in
                    SupplementRow(row: row) {
                        Task { await model.logSupplement(row.isActive ? .taken : .started, row.item) }
                    }
                    .contextMenu {
                        if row.isActive {
                            Button("Stop") { stopping = row }
                        }
                    }
                }
            }
            ForEach(plan.rules, id: \.self) { rule in
                Text(rule).textStyle(.meta).foregroundStyle(palette.graphite)
            }
            if !plan.mentioned.isEmpty {
                // Only noted: no actions, no links.
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    Text("Your provider mentioned")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(plan.mentioned) { item in
                        Text(item.text).textStyle(.meta).foregroundStyle(palette.graphite)
                    }
                }
                .padding(.top, Spacing.x4)
            }
        }
        .confirmationDialog("Stop \(stopping.map { SupplementDisplay($0.item).name } ?? "")?", isPresented: stoppingShowing, titleVisibility: .visible, presenting: stopping) { row in
            Button("Stop") { Task { await model.logSupplement(.stopped, row.item) } }
        } message: { _ in
            Text("It stays in your history. You can start it again.")
        }
    }

    private var stoppingShowing: Binding<Bool> {
        Binding(get: { stopping != nil }, set: { if !$0 { stopping = nil } })
    }
}

/// A supplement: its name (with "New" when the plan says ADD), one meta line,
/// the plan's directions behind "How to give", and the same control on the
/// right every time: "Start", then "0 of 2 today".
private struct SupplementRow: View {
    @Environment(\.palette) private var palette
    let row: SupplementPlan.Row
    let action: () -> Void
    @State private var showingHow = false

    private var display: SupplementDisplay { SupplementDisplay(row.item) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            AdaptiveStack(spacing: Spacing.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    AdaptiveStack(alignment: .firstTextBaseline, spacing: Spacing.x1) {
                        Text(display.name).textStyle(.body).foregroundStyle(palette.ink)
                        if display.isNew {
                            Text("New")
                                .textStyle(.meta)
                                .foregroundStyle(palette.indigo)
                                .padding(.horizontal, Spacing.x2)
                                .overlay(Capsule().strokeBorder(palette.indigo, lineWidth: 1))
                                .accessibilityLabel("New to the routine")
                        }
                    }
                    if let meta = display.meta {
                        Text(meta).textStyle(.meta).foregroundStyle(palette.graphite)
                    }
                    if let note {
                        Text(note).textStyle(.meta).foregroundStyle(palette.ochre)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: action) {
                    Text(status)
                        .textStyle(.meta)
                        .foregroundStyle(row.isActive ? palette.ink : palette.indigo)
                        .padding(.horizontal, Spacing.x2 + Spacing.x1)
                        .padding(.vertical, Spacing.x1)
                        .overlay(Capsule().strokeBorder(row.isActive ? palette.hairline : palette.indigo, lineWidth: 1))
                        .frame(minWidth: Size.touchTarget, minHeight: Size.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(row.isActive ? "Log \(display.name) given" : "Start \(display.name)")
                .accessibilityValue(status)
            }
            if !display.howToGive.isEmpty {
                Button { showingHow.toggle() } label: {
                    HStack(spacing: Spacing.x1) {
                        Text("How to give").textStyle(.meta)
                        Image(systemName: showingHow ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(palette.indigo)
                    .frame(minHeight: Size.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(showingHow ? "Shown" : "Hidden")
                if showingHow {
                    VStack(alignment: .leading, spacing: Spacing.x1) {
                        ForEach(display.howToGive, id: \.self) { line in
                            Text(line).textStyle(.meta).foregroundStyle(palette.ink)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.x2)
                }
            }
        }
        .padding(.vertical, Spacing.x2)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }

    /// "Start", then "0 of 2 today" (or "0 today" when the plan doesn't say how often).
    private var status: String {
        guard row.isActive else { return "Start" }
        if let perDay = row.perDay { return "\(row.takenToday) of \(perDay) today" }
        return "\(row.takenToday) today"
    }

    /// The plan's rules, as dates: "Can start after Oct 4", "Rotate after Oct 22".
    private var note: String? {
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        if let waiting = row.waitingFor { return waiting }
        if let after = row.canStartAfter, after > .now { return "Can start after \(after.formatted(format))" }
        if let rotate = row.rotateOn, row.isActive { return "Rotate after \(rotate.formatted(format))" }
        return nil
    }
}

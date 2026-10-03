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
        }
        .confirmationDialog("Stop \(stopping?.item.text ?? "")?", isPresented: stoppingShowing, titleVisibility: .visible, presenting: stopping) { row in
            Button("Stop") { Task { await model.logSupplement(.stopped, row.item) } }
        } message: { _ in
            Text("It stays in your history. You can start it again.")
        }
    }

    private var stoppingShowing: Binding<Bool> {
        Binding(get: { stopping != nil }, set: { if !$0 { stopping = nil } })
    }
}

private struct SupplementRow: View {
    @Environment(\.palette) private var palette
    let row: SupplementPlan.Row
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.item.text).textStyle(.body).foregroundStyle(palette.ink)
                    let details = [row.item.dose, row.item.frequency, row.item.timing].compactMap { $0 }
                    if !details.isEmpty {
                        Text(details.joined(separator: " · ")).textStyle(.meta).foregroundStyle(palette.graphite)
                    }
                    if let note {
                        Text(note).textStyle(.meta).foregroundStyle(palette.ochre)
                    }
                }
                Spacer()
                Text(status)
                    .textStyle(.meta)
                    .foregroundStyle(row.isActive ? palette.graphite : palette.indigo)
            }
            .padding(.vertical, Spacing.x2)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.isActive ? "Log \(row.item.text) taken" : "Start \(row.item.text)")
        .accessibilityValue(status)
    }

    /// "Start", "Taken", "1 of 2 today", or "Not yet today".
    private var status: String {
        guard row.isActive else { return "Start" }
        if let perDay = row.perDay, perDay > 1 { return "\(row.takenToday) of \(perDay) today" }
        return row.takenToday > 0 ? "Taken" : "Not yet today"
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

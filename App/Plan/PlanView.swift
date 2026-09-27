import Core
import SwiftUI

/// Plan: follow the care plan. Until routine steps exist (U2), the routine is two
/// rows, Morning and Evening; one tap logs it done. The care plan arrives in Phase 4.
struct PlanView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                if model.child != nil {
                    LedgerSection("Routine") {
                        ForEach(RoutineTime.allCases, id: \.self) { time in
                            row(for: time)
                        }
                    }
                    .padding(.vertical, Spacing.x4)
                }
            }
            .paperBackground()
            .logConfirmation(on: .plan)
            .shellToolbar(showsSwitcher: true)
        }
    }

    private func row(for time: RoutineTime) -> some View {
        let done = lastDone(time)
        return Button {
            Task { await model.log(.routineDone, value: .routine(time)) }
        } label: {
            LedgerRow {
                Text(time == .morning ? "Morning" : "Evening")
                    .textStyle(.control)
                    .foregroundStyle(palette.ink)
            } trailing: {
                if let done {
                    Text("Done \(model.time(done.timestamp))")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                }
            }
        }
        .buttonStyle(.ledger)
        .accessibilityLabel(time == .morning ? "Log morning routine done" : "Log evening routine done")
        .accessibilityValue(done.map { "Done \(model.time($0.timestamp))" } ?? "")
    }

    /// Today's most recent log for this routine.
    private func lastDone(_ time: RoutineTime) -> LogEntry? {
        model.entries.first { $0.type == .routineDone && $0.value == .routine(time) }
    }
}

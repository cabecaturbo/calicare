#if DEBUG
import Core
import SwiftUI

/// Debug builds only: starts the Phase 0 test Live Activity and shows what each
/// Lock Screen tap did (saved, failed, or never ran).
struct LockScreenTestView: View {
    @Environment(\.palette) private var palette
    @State private var lines: [LockScreenDiagnostics.Line] = []
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button("Start the test Live Activity") { Task { await start() } }
                Button("End it") { Task { await LockScreenTest.end(); reload() } }
                Button("Clear the list") { LockScreenDiagnostics.clear(); reload() }
            } footer: {
                Text(message ?? "Start it, lock the phone, then tap Log on the Lock Screen widget and on the test card. Come back here to see what happened.")
            }
            Section("What happened (newest first)") {
                if lines.isEmpty {
                    Text("Nothing yet.").foregroundStyle(palette.graphite)
                }
                ForEach(lines.reversed()) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.message).font(.callout)
                        Text("\(line.at.formatted(date: .omitted, time: .standard)) · \(line.process)")
                            .font(.caption)
                            .foregroundStyle(palette.graphite)
                    }
                }
            }
        }
        .navigationTitle("Lock Screen test")
        .onAppear(perform: reload)
        .refreshable { reload() }
    }

    private func start() async {
        guard LockScreenTest.areEnabled else {
            message = "Live Activities are off for Cali Care. Turn them on in Settings › Cali Care."
            return
        }
        do {
            try await LockScreenTest.start()
            message = "Started. Lock the phone and try it."
        } catch {
            message = "Couldn't start it: \(error.localizedDescription)"
        }
        reload()
    }

    private func reload() { lines = LockScreenDiagnostics.recent() }
}
#endif

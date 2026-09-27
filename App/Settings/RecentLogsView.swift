import Core
import SwiftUI

/// Debug list: the newest logs from anywhere, with type, child, time, and source.
struct RecentLogsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @State private var rows: [RecentLogRow] = []
    @State private var status: String?

    var body: some View {
        ScrollView {
            LedgerSection(footnote: status) {
                ForEach(rows) { row in
                    LedgerRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .textStyle(.control)
                                .foregroundStyle(palette.ink)
                            Text(row.details)
                                .textStyle(.meta)
                                .foregroundStyle(palette.graphite)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, Spacing.x4)
        }
        .paperBackground()
        .navigationTitle("Recent logs")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await load() }
            }
        }
    }

    /// Fresh stores each time, so logs written by widgets and Siri show up.
    private func load() async {
        do {
            let container = try CaliCareModelContainer.shared()
            let entries = try await LogStore(modelContainer: container).recent(limit: 50)
            let children = try await ChildStore(modelContainer: container).activeChildren()
            let names = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0.name) })
            let phrases = LogPhrases()
            rows = entries.map { entry in
                RecentLogRow(entry: entry, childName: entry.childID.flatMap { names[$0] }, phrases: phrases)
            }
            status = rows.isEmpty ? "Nothing logged yet." : nil
        } catch {
            status = "Couldn't load logs: \(error.localizedDescription)"
        }
    }
}

struct RecentLogRow: Identifiable {
    let id: UUID
    let title: String
    let details: String

    init(entry: LogEntry, childName: String?, phrases: LogPhrases) {
        id = entry.id
        title = phrases.title(for: entry)
        let when = entry.timestamp.formatted(date: .abbreviated, time: .shortened)
        let source = entry.source.rawValue.capitalized
        details = "\(childName ?? "Removed child") · \(when) · \(source)"
    }
}

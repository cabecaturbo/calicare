import Core
import SwiftUI

/// Debug list: the newest logs from anywhere, with type, child, time, and source.
struct RecentLogsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @State private var rows: [RecentLogRow] = []
    @State private var status: String?

    var body: some View {
        List {
            if let status {
                Text(status)
                    .font(Typography.callout)
                    .foregroundStyle(palette.muted)
                    .listRowBackground(palette.card)
            }
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(row.title)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(palette.ink)
                    Text(row.details)
                        .font(Typography.caption)
                        .foregroundStyle(palette.muted)
                }
                .padding(.vertical, Spacing.xxs)
                .accessibilityElement(children: .combine)
                .listRowBackground(palette.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .navigationTitle("Recent logs")
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

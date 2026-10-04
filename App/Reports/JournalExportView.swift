import Core
import SwiftUI

/// The daily journal for the provider (prompt 4.7): pick dates, then share it
/// as a PDF or a spreadsheet. Starts at the plan's start date, or 4 weeks ago.
struct JournalExportView: View {
    @Environment(\.palette) private var palette
    let child: ChildInfo
    @State private var from: Date
    @State private var to = Date.now
    @State private var files: (csv: URL, pdf: URL)?
    @State private var days = 0

    init(child: ChildInfo, from start: Date?) {
        self.child = child
        _from = State(initialValue: start ?? Calendar.current.date(byAdding: .day, value: -27, to: .now) ?? .now)
    }

    var body: some View {
        Form {
            Section {
                DatePicker("From", selection: $from, in: ...to, displayedComponents: .date)
                DatePicker("To", selection: $to, in: from...Date.now, displayedComponents: .date)
            } footer: {
                Text("Per day: what changed, rash and itch, bowel movements, sleep, and mood. \(days) days with logs. Not medical advice.")
            }
            if let files {
                Section {
                    ShareLink(item: files.pdf) { Text("Share as PDF") }
                    ShareLink(item: files.csv) { Text("Share as spreadsheet") }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .navigationTitle("Journal for your provider")
        .navigationBarTitleDisplayMode(.inline)
        .tint(palette.indigo)
        .task(id: "\(from)-\(to)") { await build() }
    }

    private func build() async {
        guard let container = try? CaliCareModelContainer.shared() else { return }
        let range = DoctorReport.Range(first: CareDay.containing(from), last: CareDay.containing(to))
        let logs = LogStore(modelContainer: container)
        let plans = CarePlanStore(modelContainer: container)
        let events = (try? await logs.events(from: range.first, through: range.last, child: child.id)) ?? []
        var items: [UUID: PlanItemInfo] = [:]
        let all = ((try? await plans.plans(child: child.id)) ?? []).filter { $0.status != .draft }
        for plan in all {
            for item in (try? await plans.items(plan: plan.id)) ?? [] { items[item.id] = item }
        }
        let products = (try? await ProductStore(modelContainer: container).products(child: child.id)) ?? []
        let changes = CareChanges.list(plans: all, items: items, logs: events, products: products)
        let journal = ProviderJournal(childName: child.name, range: range, events: events, changes: changes)
        days = journal.days.count
        files = try? ProviderJournalPDF.files(for: journal)
    }
}

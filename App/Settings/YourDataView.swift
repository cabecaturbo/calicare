import Core
import SwiftUI

/// Settings › Your data: every log as a spreadsheet, the doctor PDF for any
/// dates, and what's stored where, in plain words.
struct YourDataView: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    @State private var file: URL?
    @State private var problem: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                section("Export") {
                    if let file {
                        ShareLink(item: file) {
                            row("Every log, as a spreadsheet (CSV)")
                        }
                    } else {
                        row("Every log, as a spreadsheet (CSV)")
                            .opacity(0.5)
                    }
                    if let child = model.child {
                        NavigationLink {
                            DoctorReportView(child: child)
                        } label: {
                            row("Care log PDF, any dates")
                        }
                    }
                    Text("The spreadsheet opens in Numbers, Excel, or Google Sheets: one row per log, with the child, time, what, note, where it was logged from, and who logged it.")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    if let problem {
                        Text(problem).textStyle(.body).foregroundStyle(palette.ink)
                    }
                }

                section("What's stored where") {
                    fact("On this phone", "Everything you log, your children's names, and your routine. Widgets and Siri read the same place.")
                    fact("Photos", "Photos never leave this phone. They aren't synced or sent anywhere.")
                    fact("If you share with family", "Logs, children, and routine steps are copied to our server so everyone sees the same day. Nothing else, and never photos.")
                    fact("Never", "No ads, no selling data, no tracking.")
                }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.x5)
        }
        .paperBackground()
        .navigationTitle("Your data")
        .navigationBarTitleDisplayMode(.inline)
        .task { await makeFile() }
    }

    private func makeFile() async {
        do {
            let container = try CaliCareModelContainer.shared()
            let entries = try await LogStore(modelContainer: container).allLive()
            let children = try await ChildStore(modelContainer: container).activeChildren()
            file = try LogExport.file(LogExport.csv(entries, children: children))
        } catch {
            problem = "Couldn't make the spreadsheet just now. Please try again."
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x3) {
            Text(title)
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func row(_ title: String) -> some View {
        HStack {
            Text(title)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(palette.graphite)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        .contentShape(Rectangle())
    }

    private func fact(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Text(title)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
            Text(detail)
                .textStyle(.body)
                .foregroundStyle(palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

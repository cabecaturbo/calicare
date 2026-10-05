import Core
import MessageUI
import SwiftUI

/// Pick dates, make the PDF for a provider, then share it or email it.
struct DoctorReportView: View {
    @Environment(\.palette) private var palette
    let child: ChildInfo
    @State private var from: Date
    @State private var to: Date = .now
    @State private var report: DoctorReport?
    @State private var file: URL?
    @State private var working = false
    @State private var problem: String?
    @State private var composing = false

    /// `range` starts the dates at what Progress was showing; otherwise since
    /// the last visit, or the last 4 weeks.
    init(child: ChildInfo, lastVisit: Date? = nil, range: DoctorReport.Range? = nil) {
        self.child = child
        let range = range ?? DoctorReport.Range.standard(lastVisit: lastVisit)
        _from = State(initialValue: range.first.noon())
        _to = State(initialValue: min(range.last.noon(), .now))
    }

    private var range: DoctorReport.Range {
        DoctorReport.Range(first: CareDay.containing(from), last: CareDay.containing(to))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                VStack(alignment: .leading, spacing: Spacing.titleToLede) {
                    Text("A care log for \(child.name)'s provider")
                        .textStyle(.title)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("A PDF of what was logged: counts, a sleep and itch chart, day by day, notes, and every log. No conclusions, and every page says it isn't medical advice.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.margin)

                LedgerSection("Dates", footnote: "Starts 4 weeks back. Change it to cover since the last visit.") {
                    dateRow("From") {
                        DatePicker("From", selection: $from, in: ...to, displayedComponents: .date)
                    }
                    dateRow("To") {
                        DatePicker("To", selection: $to, in: from...Date.now, displayedComponents: .date)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.x4) {
                    if let file {
                        if let report {
                            Text("\(report.daysWithLogs) days with logs, \(report.rows.count) logs in all.")
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                        }
                        ShareLink(item: file) { Text("Share PDF") }
                            .buttonStyle(.primary)
                        if MFMailComposeViewController.canSendMail() {
                            Button("Email to provider") { composing = true }
                                .buttonStyle(.secondary)
                        }
                    } else {
                        Button(working ? "Making the PDF…" : "Make PDF") { Task { await make() } }
                            .buttonStyle(.primary)
                            .disabled(working)
                    }
                    if let problem {
                        Text(problem)
                            .textStyle(.body)
                            .foregroundStyle(palette.ink)
                    }
                }
                .padding(.horizontal, Spacing.margin)
            }
            .padding(.vertical, Spacing.x4)
        }
        .paperBackground()
        .navigationTitle("Doctor report")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: from) { file = nil }
        .onChange(of: to) { file = nil }
        .sheet(isPresented: $composing) {
            if let file, let report {
                MailComposer(
                    subject: "Care log for \(child.name), \(report.dateRange)",
                    body: "Attached is a log of what we recorded for \(child.name) from \(report.dateRange). It's what we logged at home, not medical advice.",
                    attachment: file
                )
                .ignoresSafeArea()
            }
        }
    }

    private func dateRow(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        LedgerRow {
            Text(title)
                .textStyle(.control)
                .foregroundStyle(palette.ink)
        } trailing: {
            picker()
                .labelsHidden()
                .tint(palette.accent)
        }
    }

    private func make() async {
        working = true
        defer { working = false }
        do {
            let container = try CaliCareModelContainer.shared()
            let report = try await DoctorReport.load(child: child, range: range, container: container)
            self.report = report
            file = try DoctorReportPDF.file(for: report)
            problem = nil
        } catch {
            problem = "Couldn't make the PDF just now. Try again in a moment."
        }
    }
}

/// Mail with the PDF attached, for "Email to provider".
private struct MailComposer: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let subject: String
    let body: String
    let attachment: URL

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setSubject(subject)
        mail.setMessageBody(body, isHTML: false)
        if let data = try? Data(contentsOf: attachment) {
            mail.addAttachmentData(data, mimeType: "application/pdf", fileName: attachment.lastPathComponent)
        }
        return mail
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: (any Error)?) {
            // Mail calls back on the main thread.
            let dismiss = self.dismiss
            MainActor.assumeIsolated { dismiss() }
        }
    }
}

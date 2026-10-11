import Core
import MessageUI
import SwiftUI

/// Pick dates, make the one-page report for the doctor, then share or email it.
struct DoctorReportView: View {
    @Environment(\.palette) private var palette
    let child: ChildInfo
    @State private var from: Date
    @State private var to: Date = .now
    @State private var report: VisitReport?
    /// The parent moved a date, so the last visit no longer sets the start.
    @State private var picked = false
    private let hasRange: Bool
    @State private var file: URL?
    @State private var working = false
    @State private var problem: String?
    @State private var composing = false

    /// `range` starts the dates at what Progress was showing; otherwise since
    /// the last visit, or the last 4 weeks.
    init(child: ChildInfo, lastVisit: Date? = nil, range: DoctorReport.Range? = nil) {
        self.child = child
        hasRange = range != nil || lastVisit != nil
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
                    Text("A report for \(child.name)’s doctor")
                        .textStyle(.title)
                        .foregroundStyle(palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("One page: skin week by week, how the plan is going, your notes and questions. Only what you logged, and it says it isn’t medical advice.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.margin)

                LedgerSection("Dates", footnote: "Starts at the last visit, or 4 weeks back.") {
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
                            Text(report.summary)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ShareLink(item: file) { Text("Share PDF") }
                            .buttonStyle(.primary)
                        if MFMailComposeViewController.canSendMail() {
                            Button("Email to the doctor") { composing = true }
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
        .task { await startAtLastVisit() }
        .sheet(isPresented: $composing) {
            if let file, let report {
                MailComposer(
                    subject: report.title,
                    body: "Attached is a one-page report of what we logged at home for \(child.name). It isn’t medical advice.",
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

    /// With no range given, start at the last visit (if there was one).
    private func startAtLastVisit() async {
        guard !hasRange, !picked, let container = try? CaliCareModelContainer.shared(),
              let last = try? await CarePlanStore(modelContainer: container).lastVisit(child: child.id)
        else { return }
        from = DoctorReport.Range.standard(lastVisit: last.date).first.noon()
    }

    private func make() async {
        working = true
        defer { working = false }
        do {
            let container = try CaliCareModelContainer.shared()
            let plans = CarePlanStore(modelContainer: container)
            let range = range
            let events = try await LogStore(modelContainer: container).events(from: range.first, through: range.last, child: child.id)
            let plan = try await plans.activePlan(child: child.id)
            var items: [PlanItemInfo] = []
            if let plan { items = try await plans.items(plan: plan.id) }
            let steps = try await RoutineStore(modelContainer: container).steps(child: child.id)
            let visits = try await plans.visits(child: child.id)
            let report = VisitReport(child: child, range: range, events: events, plan: plan, items: items, steps: steps,
                                     visits: visits, parentName: LoggedBy.current())
            self.report = report
            file = try VisitReportPDF.file(for: report)
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

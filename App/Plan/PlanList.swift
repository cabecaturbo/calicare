import Core
import PDFKit
import SwiftUI

/// One list row: a label in ink, one meta line, a chevron. The whole row is
/// the tap target; VoiceOver reads "label, meta, button".
struct PlanListRow<Leading: View>: View {
    @Environment(\.palette) private var palette
    let label: String
    let meta: String?
    var minHeight: CGFloat = 64
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: Spacing.x4) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(label).textStyle(.body).foregroundStyle(palette.ink)
                if let meta {
                    Text(meta).textStyle(.meta).foregroundStyle(palette.graphite)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.graphite)
        }
        .padding(.vertical, Spacing.x3)
        .frame(minHeight: minHeight)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([label, meta].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }
}

extension PlanListRow where Leading == EmptyView {
    init(label: String, meta: String?, minHeight: CGFloat = 64) {
        self.init(label: label, meta: meta, minHeight: minHeight) { EmptyView() }
    }
}

/// The original plan file, kept on this phone.
enum PlanDocument {
    static func url(_ plan: CarePlanInfo) -> URL? {
        guard let name = plan.sourceFileName else { return nil }
        let url = PlanFiles.url(for: name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// "From Oct 5 · 2 pages"
    static func meta(_ plan: CarePlanInfo) -> String? {
        let date = (plan.planDate ?? plan.startedAt).map { "From \(PlanWords.day($0))" }
        let count = url(plan).flatMap { PDFDocument(url: $0)?.pageCount } ?? 0
        let pages = count == 0 ? nil : count == 1 ? "1 page" : "\(count) pages"
        let line = [date, pages].compactMap { $0 }.joined(separator: " · ")
        return line.isEmpty ? nil : line
    }
}

/// Plan › Open the full plan: the original document, with "About this plan".
struct PlanDocumentScreen: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let plan: CarePlanInfo
    @State private var showingAbout = false

    var body: some View {
        Group {
            if let url = PlanDocument.url(plan) {
                PDFDocumentView(url: url)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(alignment: .leading, spacing: Spacing.x3) {
                    Text("The original file isn't on this phone.")
                        .textStyle(.body)
                        .foregroundStyle(palette.ink)
                    Text("Plans read on another phone keep their file there. Every item is in About this plan.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(Spacing.margin)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .paperBackground()
        .solidNavigationBar(.paper)
        .navigationTitle("Full plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("About this plan") { showingAbout = true }
            }
        }
        .sheet(isPresented: $showingAbout, onDismiss: { Task { await model.load() } }) {
            AboutPlanView(plan: plan).nightAwarePalette()
        }
    }
}

/// PDFKit's viewer, pages stacked, fit to width.
private struct PDFDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}

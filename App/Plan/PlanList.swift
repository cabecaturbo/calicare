import Core
import PDFKit
import SwiftUI

/// A running plan, read first (canvas "Plan v3"): "Open the full plan",
/// then the plan by section. Every row opens its own page; nothing on this
/// list changes anything.
struct PlanList: View {
    @Environment(\.palette) private var palette
    @Environment(TodayModel.self) private var model
    let plan: CarePlanInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink { PlanDocumentScreen(plan: plan) } label: {
                PlanListRow(label: "Open the full plan", meta: PlanDocument.meta(plan), minHeight: 80) {
                    PlanThumbnail()
                }
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { palette.hairline.frame(height: Rule.width) }

            ForEach(model.planEntries.sections, id: \.section) { section, entries in
                Text(section.title)
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Spacing.x6)
                    .padding(.bottom, Spacing.x2)
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        NavigationLink { PlanItemScreen(id: entry.id) } label: {
                            PlanListRow(label: entry.label, meta: entry.meta)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(alignment: .top) { palette.hairline.frame(height: Rule.width) }
            }
        }
        .padding(.top, Spacing.x5)
    }
}

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

/// A plan page drawn small. Paper is white in both palettes, so it keeps the day ink.
private struct PlanThumbnail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(Palette.day.ink).frame(width: 25, height: 3)
            ForEach([1.0, 0.7, 1.0, 0.6], id: \.self) { width in
                Rectangle().fill(Palette.day.hairline).frame(width: 31 * width, height: 2)
            }
        }
        .padding(EdgeInsets(top: 7, leading: 6, bottom: 7, trailing: 6))
        .frame(width: 44, height: 56, alignment: .topLeading)
        .background(Color.white)
        .overlay(Rectangle().strokeBorder(Palette.day.hairline, lineWidth: 1))
        .accessibilityHidden(true)
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
        .sheet(isPresented: $showingAbout) {
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

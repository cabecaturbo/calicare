import Core
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// Plan › "Add your care plan": scan the pages, pick a PDF, or pick photos.
/// The phone reads the text; only the text is sent to pick out the items.
/// The file stays on this phone. Ends on the review screen as a draft.
struct AddPlanSheet: View {
    enum Stage: Equatable {
        case choose
        case reading(String)
        case failed(String)
    }

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountController.self) private var account
    let child: ChildInfo
    let onDraft: (CarePlanInfo) -> Void

    @State private var stage: Stage = .choose
    @State private var provider = ""
    @State private var scanning = false
    @State private var importing = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var signingIn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    Text("You’ll check each item before it starts.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)

                    switch stage {
                    case .choose:
                        if isSignedIn { choices } else { signInFirst }
                    case .reading(let step):
                        HStack(spacing: Spacing.x4) {
                            ProgressView()
                            Text(step).textStyle(.body).foregroundStyle(palette.ink)
                        }
                    case .failed(let message):
                        VStack(alignment: .leading, spacing: Spacing.x4) {
                            Text(message)
                                .textStyle(.body)
                                .foregroundStyle(palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Try again") { stage = .choose }
                                .buttonStyle(.textLink)
                        }
                    }

                    Text("The file stays on your phone. Not medical advice.")
                        .textStyle(.meta)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.x5)
            }
            .paperBackground()
            .solidNavigationBar(.paper)
            .navigationTitle("Add your care plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(palette.indigo)
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { images in
                scanning = false
                if !images.isEmpty { Task { await read(images: images) } }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }
            Task { await read(files: urls) }
        }
        .onChange(of: photos) { _, picked in
            guard !picked.isEmpty else { return }
            Task { await read(photos: picked) }
        }
        .sheet(isPresented: $signingIn) {
            AccountSheet()
                .environment(account)
                .nightAwarePalette()
        }
    }

    private var isSignedIn: Bool {
        if case .signedIn = account.state { return true }
        return false
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                Text("Provider")
                    .textStyle(.section)
                    .foregroundStyle(palette.ink)
                TextField("Name (optional)", text: $provider)
                    .textStyle(.body)
                    .textContentType(.name)
                    .padding(Spacing.x4)
                    .background(palette.oat, in: RoundedRectangle(cornerRadius: Corner.control))
            }
            if VNDocumentCameraViewController.isSupported {
                Button { scanning = true } label: { ChoiceLabel(title: "Scan the pages", symbol: "camera.viewfinder") }
                    .buttonStyle(.plain)
            }
            Button { importing = true } label: { ChoiceLabel(title: "Choose a PDF or file", symbol: "doc") }
                .buttonStyle(.plain)
            PhotosPicker(selection: $photos, maxSelectionCount: 20, matching: .images) {
                ChoiceLabel(title: "Choose photos", symbol: "photo.on.rectangle")
            }
            .buttonStyle(.plain)
        }
    }

    private var signInFirst: some View {
        VStack(alignment: .leading, spacing: Spacing.x4) {
            Text("Sign in once to read plans.")
                .textStyle(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button("Sign in with Apple") { signingIn = true }
                .buttonStyle(.primary)
        }
    }

    // MARK: - Reading

    private func read(images: [UIImage]) async {
        await read {
            let text = try await PlanTextExtractor.text(fromImages: images)
            return (text, try PlanFiles.savePDF(from: images))
        }
    }

    private func read(photos items: [PhotosPickerItem]) async {
        photos = []
        await read {
            var images: [UIImage] = []
            for item in items {
                if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            let text = try await PlanTextExtractor.text(fromImages: images)
            return (text, try PlanFiles.savePDF(from: images))
        }
    }

    private func read(files urls: [URL]) async {
        await read {
            if let pdf = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) {
                let name = try PlanFiles.savePDF(from: pdf)
                return (try await PlanTextExtractor.text(fromPDF: PlanFiles.url(for: name)), name)
            }
            let images = urls.compactMap { url -> UIImage? in
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                return (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
            }
            let text = try await PlanTextExtractor.text(fromImages: images)
            return (text, try PlanFiles.savePDF(from: images))
        }
    }

    /// Reads the text on the phone, sends only the text, and saves a draft.
    private func read(_ extract: () async throws -> (text: String, file: String)) async {
        stage = .reading("Reading the pages…")
        var file: String?
        do {
            let extracted = try await extract()
            file = extracted.file
            stage = .reading("Finding each item…")
            let items = try await PlanReader.read(extracted.text)
            guard !items.isEmpty else {
                PlanFiles.delete(file)
                stage = .failed("We couldn’t find plan items in that. Try clearer photos, or the PDF your provider sent.")
                return
            }
            let plan = try await CarePlanStore(modelContainer: try CaliCareModelContainer.shared())
                .createDraft(child: child.id, provider: provider, sourceFileName: extracted.file, items: items)
            dismiss()
            onDraft(plan)
        } catch PlanTextExtractor.Failure.noText {
            PlanFiles.delete(file)
            stage = .failed("We couldn’t read any words in that. Try clearer photos, in good light, or the PDF.")
        } catch PlanReader.Failure.notSignedIn {
            PlanFiles.delete(file)
            stage = .choose
        } catch PlanReader.Failure.tooMany {
            PlanFiles.delete(file)
            stage = .failed("That’s a lot of plans for one day. Please try again tomorrow.")
        } catch {
            PlanFiles.delete(file)
            stage = .failed("Couldn’t read the plan just now. Check your connection and try again.")
        }
    }
}

/// One way to add the plan: a symbol and a label on a paper card.
private struct ChoiceLabel: View {
    @Environment(\.palette) private var palette
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: Spacing.x4) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(palette.indigo)
                .frame(width: 28)
            Text(title)
                .textStyle(.body)
                .foregroundStyle(palette.ink)
            Spacer()
        }
        .padding(.horizontal, Spacing.x4)
        .frame(minHeight: 56)
        .background(palette.paper, in: RoundedRectangle(cornerRadius: Corner.card))
        .overlay(RoundedRectangle(cornerRadius: Corner.card).strokeBorder(palette.hairline, lineWidth: 1))
    }
}

/// VisionKit's document camera: finds page edges and flattens each page.
private struct DocumentScanner: UIViewControllerRepresentable {
    let onFinish: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void

        init(onFinish: @escaping ([UIImage]) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish((0..<scan.pageCount).map(scan.imageOfPage(at:)))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish([])
        }
    }
}

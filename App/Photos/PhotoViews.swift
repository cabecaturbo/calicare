import Core
import PhotosUI
import SwiftUI
import UIKit

/// Progress › Photos: spots with their latest photo. Photos stay on this phone.
struct PhotosSection: View {
    @Environment(\.palette) private var palette
    let child: ChildInfo
    @State private var spots: [PhotoLibrary.Spot] = []
    @State private var naming = false
    @State private var newName = ""

    private var library: PhotoLibrary { PhotoLibrary(root: PhotoLibrary.appRoot(), child: child.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            Text("Photos")
                .textStyle(.section)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(spots) { spot in
                NavigationLink {
                    SpotTimelineView(library: library, spot: spot)
                } label: {
                    SpotRow(library: library, spot: spot)
                }
                .buttonStyle(.plain)
            }
            Button("Add a spot") { naming = true }
                .buttonStyle(.textLink)
            Text("Photos stay on this phone. They're never synced, sent, or put in reports.")
                .textStyle(.meta)
                .foregroundStyle(palette.graphite)
        }
        .task { reload() }
        .alert("Name the spot", isPresented: $naming) {
            TextField("Left elbow", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                _ = try? library.addSpot(newName)
                newName = ""
                reload()
            }
        }
    }

    private func reload() {
        spots = (try? library.spots()) ?? []
    }
}

private struct SpotRow: View {
    @Environment(\.palette) private var palette
    let library: PhotoLibrary
    let spot: PhotoLibrary.Spot

    var body: some View {
        let photos = (try? library.photos(spot: spot.id)) ?? []
        HStack(spacing: Spacing.x3) {
            Thumbnail(url: photos.last.map(library.url(for:)))
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name).textStyle(.body).foregroundStyle(palette.ink)
                Text(photos.isEmpty ? "No photos yet" : "\(photos.count) photo\(photos.count == 1 ? "" : "s") · last \(photos.last!.takenAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .textStyle(.meta)
                    .foregroundStyle(palette.graphite)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.graphite)
        }
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { palette.hairline.frame(height: Rule.width) }
    }
}

/// One spot's photos over time, newest first, and adding the next one.
struct SpotTimelineView: View {
    @Environment(\.palette) private var palette
    let library: PhotoLibrary
    let spot: PhotoLibrary.Spot
    @State private var photos: [PhotoLibrary.Photo] = []
    @State private var camera = false
    @State private var picked: PhotosPickerItem?
    @State private var viewing: PhotoLibrary.Photo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                HStack(spacing: Spacing.x4) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take a photo") { camera = true }.buttonStyle(.primary)
                    }
                    PhotosPicker(selection: $picked, matching: .images) {
                        LinkLabel(title: "Choose a photo")
                    }
                }
                if photos.isEmpty {
                    Text("Take the first photo. Next time, the last one shows faintly so you can line it up.")
                        .textStyle(.body)
                        .foregroundStyle(palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.x2), GridItem(.flexible())], spacing: Spacing.x2) {
                    ForEach(photos.reversed()) { photo in
                        Button { viewing = photo } label: {
                            VStack(alignment: .leading, spacing: Spacing.x1) {
                                Thumbnail(url: library.url(for: photo))
                                    .aspectRatio(1, contentMode: .fit)
                                Text(photo.takenAt.formatted(.dateTime.month(.abbreviated).day()))
                                    .textStyle(.meta)
                                    .foregroundStyle(palette.graphite)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete photo") {
                                try? library.deletePhoto(photo.id)
                                reload()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.x5)
        }
        .paperBackground()
        .navigationTitle(spot.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .fullScreenCover(isPresented: $camera) {
            GhostCamera(ghost: photos.last.flatMap { UIImage(contentsOfFile: library.url(for: $0).path) }) { image in
                camera = false
                if let data = image?.jpegData(compressionQuality: 0.85) {
                    _ = try? library.addPhoto(data, spot: spot.id)
                    reload()
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) {
                    _ = try? library.addPhoto(jpeg, spot: spot.id)
                    reload()
                }
                picked = nil
            }
        }
        .sheet(item: $viewing) { photo in
            PhotoViewer(url: library.url(for: photo), date: photo.takenAt)
        }
    }

    private func reload() {
        photos = (try? library.photos(spot: spot.id)) ?? []
    }
}

private struct Thumbnail: View {
    @Environment(\.palette) private var palette
    let url: URL?

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                palette.oat
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Corner.image))
        .accessibilityHidden(true)
    }
}

private struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    let date: Date

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// The camera with the last photo of this spot shown faintly on top, to line up the next one.
private struct GhostCamera: UIViewControllerRepresentable {
    let ghost: UIImage?
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        if let ghost {
            let overlay = UIImageView(image: ghost)
            overlay.contentMode = .scaleAspectFit
            overlay.alpha = 0.35
            overlay.isUserInteractionEnabled = false
            let bounds = UIScreen.main.bounds
            overlay.frame = CGRect(x: 0, y: bounds.height * 0.12, width: bounds.width, height: bounds.width * 4 / 3)
            picker.cameraOverlayView = overlay
        }
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

/// Indigo link text, as its own view so a picker's label can use it.
private struct LinkLabel: View {
    @Environment(\.palette) private var palette
    let title: String

    var body: some View {
        Text(title).textStyle(.body).foregroundStyle(palette.indigo)
    }
}

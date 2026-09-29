import PDFKit
import UIKit
import Vision

/// Turns a care plan (a PDF, or photos of its pages) into text on the phone,
/// with "--- Page N ---" markers so every item can point back to its page.
/// Only this text is sent to be read; the file itself never leaves the phone.
enum PlanTextExtractor {
    enum Failure: Error {
        case unreadable
        case noText
    }

    /// Text from a PDF's pages. Scanned PDFs (pictures of text) fall back to
    /// reading each page's picture.
    static func text(fromPDF url: URL) async throws -> String {
        guard let document = PDFDocument(url: url) else { throw Failure.unreadable }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            var text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                let image = page.thumbnail(of: CGSize(width: 1700, height: 2200), for: .mediaBox)
                text = try await recognize(image)
            }
            pages.append(text)
        }
        return try marked(pages)
    }

    /// Text from photos or scans, one per page, in order.
    static func text(fromImages images: [UIImage]) async throws -> String {
        var pages: [String] = []
        for image in images {
            pages.append(try await recognize(image))
        }
        return try marked(pages)
    }

    private static func marked(_ pages: [String]) throws -> String {
        guard pages.contains(where: { !$0.isEmpty }) else { throw Failure.noText }
        return pages.enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element)" }
            .joined(separator: "\n")
    }

    /// Vision's accurate text recognition, lines in reading order, off the main thread.
    private static func recognize(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw Failure.unreadable }
        let orientation = image.cgOrientation
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

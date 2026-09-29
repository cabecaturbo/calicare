import Foundation
import UIKit

/// The original care plan files, kept on this phone only (Application
/// Support/Plans, excluded from iCloud backup). CarePlan.sourceFileName
/// points here; it's never synced.
enum PlanFiles {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = base.appendingPathComponent("Plans", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return url
    }

    static func url(for name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    /// Copies a picked PDF in. Returns the stored file's name.
    static func savePDF(from source: URL) throws -> String {
        let name = "plan-\(UUID().uuidString).pdf"
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: source, to: url(for: name))
        return name
    }

    /// Saves photos or scans as one PDF, a page each. Returns the file's name.
    static func savePDF(from images: [UIImage]) throws -> String {
        let name = "plan-\(UUID().uuidString).pdf"
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for image in images {
                context.beginPage()
                let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                image.draw(in: CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                                      width: size.width, height: size.height))
            }
        }
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtection])
        return name
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: url(for: name))
    }
}

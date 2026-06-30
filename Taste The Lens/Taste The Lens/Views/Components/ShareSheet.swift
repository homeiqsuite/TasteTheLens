import UIKit

/// Writes short-lived export/share files to disk with at-rest encryption,
/// excludes them from iCloud/iTunes backup, and cleans them up after use.
/// Used for PDF and data-export shares that contain user content / PII.
enum TempFileManager {
    /// Writes `data` to a uniquely-named temp file with complete file protection
    /// (encrypted while the device is locked) and excluded from backup.
    /// Returns the file URL, or nil on failure.
    static func write(_ data: Data, fileName: String) -> URL? {
        let safe = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        // A unique subfolder per write avoids collisions between concurrent shares
        // of the same name and lets cleanup remove the whole folder.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = dir.appendingPathComponent(safe.isEmpty ? "export" : safe)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: url, options: [.completeFileProtection, .atomic])
            var fileURL = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? fileURL.setResourceValues(values)
            return url
        } catch {
            return nil
        }
    }

    /// Removes a temp file (and its unique parent folder) created by `write`.
    static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

/// Presents a system share sheet from the top-most view controller.
/// Consolidates the duplicated UIActivityViewController presentation logic.
enum SharePresenter {
    @MainActor
    static func present(_ items: [Any], cleanupURLs: [URL] = []) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // Delete any temp files once the share sheet is dismissed (completed or cancelled).
        if !cleanupURLs.isEmpty {
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                for url in cleanupURLs { TempFileManager.cleanup(url) }
            }
        }
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let pop = activityVC.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(activityVC, animated: true)
    }

    /// Writes PDF data to a protected temp file, shares it, and cleans up afterward.
    @MainActor
    static func presentPDF(_ data: Data, fileName: String) {
        if let url = TempFileManager.write(data, fileName: "\(fileName).pdf") {
            present([url], cleanupURLs: [url])
        } else {
            present([data])
        }
    }
}

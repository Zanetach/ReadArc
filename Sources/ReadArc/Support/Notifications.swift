import Foundation
import ReadArcCore

extension Notification.Name {
    static let readArcOpenFileRequested = Notification.Name("ReadArcOpenFileRequested")
}

@MainActor
final class ExternalOpenRequestCenter {
    static let shared = ExternalOpenRequestCenter()

    private var pendingURLs: [URL] = []

    private init() {}

    func enqueue(_ urls: [URL]) {
        let pdfURLs = PDFOpenPlanner.documentWindowURLs(from: urls)
        guard !pdfURLs.isEmpty else { return }

        pendingURLs.append(contentsOf: pdfURLs)
        NotificationCenter.default.post(name: .readArcOpenFileRequested, object: nil)
    }

    func drainPendingURLs() -> [URL] {
        let urls = pendingURLs
        pendingURLs.removeAll()
        return urls
    }
}

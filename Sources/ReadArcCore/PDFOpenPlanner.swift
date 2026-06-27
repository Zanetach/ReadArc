import Foundation

public enum PDFOpenPlanner {
    public static func documentWindowURLs(from urls: [URL]) -> [URL] {
        urls.filter { $0.pathExtension.lowercased() == "pdf" }
    }

    public static func uniqueDocumentWindowURLs(from urls: [URL]) -> [URL] {
        var seenKeys = Set<String>()
        var uniqueURLs: [URL] = []

        for url in documentWindowURLs(from: urls) {
            let standardizedURL = standardizedDocumentURL(url)
            let key = documentWindowKey(for: standardizedURL)
            guard seenKeys.insert(key).inserted else { continue }
            uniqueURLs.append(standardizedURL)
        }

        return uniqueURLs
    }

    public static func standardizedDocumentURL(_ url: URL) -> URL {
        url.standardizedFileURL
    }

    public static func documentWindowKey(for url: URL) -> String {
        standardizedDocumentURL(url).path
    }
}

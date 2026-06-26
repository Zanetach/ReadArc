import Combine
import Foundation

@MainActor
public final class RecentDocumentsStore: ObservableObject {
    @Published public private(set) var documents: [RecentDocument]

    private let defaults: UserDefaults
    private let storageKey: String
    private let limit: Int

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "recentPDFDocuments",
        limit: Int = 12
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.limit = limit
        self.documents = Self.loadDocuments(from: defaults, key: storageKey)
    }

    public func add(url: URL, title: String? = nil, openedAt: Date = Date(), bookmarkData: Data? = nil) {
        let document = RecentDocument(url: url, title: title, lastOpened: openedAt, bookmarkData: bookmarkData)
        var next = documents.filter { $0.url != url }
        next.insert(document, at: 0)
        documents = Array(next.prefix(limit))
        save()
    }

    public func remove(_ document: RecentDocument) {
        documents.removeAll { $0.id == document.id }
        save()
    }

    @discardableResult
    public func remove(url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let previousCount = documents.count
        documents.removeAll { $0.url.standardizedFileURL.path == path }
        guard documents.count != previousCount else {
            return false
        }

        save()
        return true
    }

    public func clear() {
        documents = []
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(documents) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadDocuments(from defaults: UserDefaults, key: String) -> [RecentDocument] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentDocument].self, from: data) else {
            return []
        }

        return decoded
    }
}

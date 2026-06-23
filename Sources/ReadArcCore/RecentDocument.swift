import Foundation

public struct RecentDocument: Codable, Equatable, Identifiable {
    public let url: URL
    public let title: String
    public let lastOpened: Date

    public var id: String {
        url.path
    }

    public init(url: URL, title: String? = nil, lastOpened: Date = Date()) {
        self.url = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.lastOpened = lastOpened
    }
}

import Foundation

public struct SearchTextMatch: Equatable, Sendable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

public enum SearchTextLocator {
    public static func firstMatch(in text: String, query: String) -> SearchTextMatch? {
        guard let range = text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) else {
            return nil
        }

        return match(in: text, range: range)
    }

    public static func match(in text: String, range: Range<String.Index>) -> SearchTextMatch {
        let location = text.utf16.distance(from: text.utf16.startIndex, to: range.lowerBound.samePosition(in: text.utf16) ?? text.utf16.startIndex)
        let length = text.utf16.distance(
            from: range.lowerBound.samePosition(in: text.utf16) ?? text.utf16.startIndex,
            to: range.upperBound.samePosition(in: text.utf16) ?? text.utf16.startIndex
        )
        return SearchTextMatch(location: location, length: length)
    }
}

import Foundation
import PDFKit

enum ReaderMode: String, CaseIterable, Identifiable {
    case nativePro
    case focus
    case research

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .nativePro:
            "Read"
        case .focus:
            "Focus"
        case .research:
            "Research"
        }
    }
}

struct SearchMatch: Identifiable, Sendable {
    let id: Int
    let index: Int
    let pageIndex: Int
    let matchLocation: Int
    let matchLength: Int
    let pageLabel: String
    let excerpt: String
}

struct SearchOutput: Sendable {
    let results: [SearchMatch]
    let truncated: Bool
}

struct LoadedPDFPayload: @unchecked Sendable {
    let document: PDFDocument
    let pageCount: Int
    let outlineItems: [DocumentOutlineItem]
    let pageTexts: [DocumentPageText]
}

struct DocumentOutlineItem: Identifiable, Sendable {
    let id: String
    let title: String
    let pageIndex: Int?
    let depth: Int

    var pageLabel: String {
        guard let pageIndex else { return "-" }
        return "\(pageIndex + 1)"
    }
}

struct DocumentPageText: Identifiable, Sendable {
    let pageIndex: Int
    let text: String

    var id: Int {
        pageIndex
    }

    var pageNumber: Int {
        pageIndex + 1
    }
}

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

struct ReaderPanelState: Equatable {
    var isInspectorVisible: Bool
    var rightPanelMode: RightPanelMode
    var inspectorTab: InspectorTab
    var readerMode: ReaderMode

    static let `default` = ReaderPanelState(
        isInspectorVisible: false,
        rightPanelMode: .research,
        inspectorTab: .search,
        readerMode: .nativePro
    )

    func updating(
        isInspectorVisible: Bool? = nil,
        rightPanelMode: RightPanelMode? = nil,
        inspectorTab: InspectorTab? = nil,
        readerMode: ReaderMode? = nil
    ) -> ReaderPanelState {
        ReaderPanelState(
            isInspectorVisible: isInspectorVisible ?? self.isInspectorVisible,
            rightPanelMode: rightPanelMode ?? self.rightPanelMode,
            inspectorTab: inspectorTab ?? self.inspectorTab,
            readerMode: readerMode ?? self.readerMode
        )
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
    let displayTitle: String
    let pageCount: Int
    let processingURL: URL
    let processingBookmarkData: Data?
}

struct PDFIndexPayload: Sendable {
    let displayTitle: String
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

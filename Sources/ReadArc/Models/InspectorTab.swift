import Foundation

enum InspectorTab: String, CaseIterable, Identifiable {
    case search
    case outline
    case notes

    var id: Self { self }

    var title: String {
        switch self {
        case .search:
            return "Search"
        case .outline:
            return "Outline"
        case .notes:
            return "Notes"
        }
    }

    var systemImage: String {
        switch self {
        case .search:
            return "magnifyingglass"
        case .outline:
            return "list.bullet.rectangle"
        case .notes:
            return "note.text"
        }
    }

    var summary: String {
        switch self {
        case .search:
            return "Search matches and evidence in the current PDF."
        case .outline:
            return "Navigate the document structure and page outline."
        case .notes:
            return "Review page-linked notes and annotations."
        }
    }
}

import Foundation

enum InspectorTab: String, CaseIterable, Identifiable {
    case search
    case outline
    case notes

    var id: Self { self }

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        language.text(titleKey)
    }

    func summary(language: AppLanguage) -> String {
        language.text(summaryKey)
    }

    private var titleKey: String {
        switch self {
        case .search:
            return "inspector.search"
        case .outline:
            return "inspector.outline"
        case .notes:
            return "inspector.notes"
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

    private var summaryKey: String {
        switch self {
        case .search:
            return "inspector.search.summary"
        case .outline:
            return "inspector.outline.summary"
        case .notes:
            return "inspector.notes.summary"
        }
    }
}

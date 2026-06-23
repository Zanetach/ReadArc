import Foundation

enum RightPanelMode: String, CaseIterable, Identifiable {
    case chat
    case focus
    case research

    var id: String {
        rawValue
    }

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        language.text(titleKey)
    }

    func subtitle(language: AppLanguage) -> String {
        language.text(subtitleKey)
    }

    private var titleKey: String {
        switch self {
        case .chat:
            return "panel.chat"
        case .focus:
            return "panel.focus"
        case .research:
            return "panel.research"
        }
    }

    private var subtitleKey: String {
        switch self {
        case .chat:
            return "panel.chat.subtitle"
        case .focus:
            return "panel.focus.subtitle"
        case .research:
            return "panel.research.subtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .focus:
            return "scope"
        case .research:
            return "magnifyingglass"
        }
    }
}

enum ChatAgentProvider: String, CaseIterable, Identifiable {
    case codexCLI
    case claudeCode

    var id: String {
        rawValue
    }

    var title: String {
        "ReadArc"
    }

    var pickerTitle: String {
        switch self {
        case .codexCLI:
            return "Codex"
        case .claudeCode:
            return "Claude Code"
        }
    }

    var commandName: String {
        switch self {
        case .codexCLI:
            return "codex"
        case .claudeCode:
            return "claude"
        }
    }

    var systemImage: String {
        switch self {
        case .codexCLI:
            return "terminal"
        case .claudeCode:
            return "curlybraces"
        }
    }
}

struct ChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var text: String
    let agent: ChatAgentProvider?
    var isStreaming = false
    let createdAt = Date()
    var completedAt: Date?
}

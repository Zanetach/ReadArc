import Foundation

enum RightPanelMode: String, CaseIterable, Identifiable {
    case inspector
    case chat

    var id: String {
        rawValue
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

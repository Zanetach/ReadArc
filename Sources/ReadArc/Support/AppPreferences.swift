import AppKit
import SwiftUI

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .system:
            return "appearance.system"
        case .light:
            return "appearance.light"
        case .dark:
            return "appearance.dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var appKitAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

extension Notification.Name {
    static let readArcSystemAppearanceChanged = Notification.Name("ReadArcSystemAppearanceChanged")
}

enum AppAppearanceController {
    @MainActor
    static func apply(_ mode: AppAppearanceMode) {
        NSApp.appearance = mode.appKitAppearance

        for window in NSApp.windows {
            window.appearance = mode.appKitAppearance
            window.contentView?.appearance = mode.appKitAppearance
            window.contentView?.needsDisplay = true
            window.viewsNeedDisplay = true
        }
    }

    @MainActor
    static func resolvedColorScheme(for mode: AppAppearanceMode) -> ColorScheme {
        switch mode {
        case .system:
            return currentSystemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    @MainActor
    static var currentSystemColorScheme: ColorScheme {
        let application = NSApplication.shared
        if application.isRunning {
            let appearance = application.effectiveAppearance
            if let match = appearance.bestMatch(from: [.darkAqua, .aqua]) {
                return match == .darkAqua ? .dark : .light
            }
        }

        return persistedSystemColorScheme
    }

    static func requestSystemAppearanceRefresh() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .readArcSystemAppearanceChanged, object: nil)
        }
    }

    private static var persistedSystemColorScheme: ColorScheme {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String {
        rawValue
    }

    var titleKey: String {
        switch self {
        case .system:
            return "language.system"
        case .english:
            return "language.english"
        case .simplifiedChinese:
            return "language.chinese"
        }
    }

    var resolved: AppLanguage {
        switch self {
        case .system:
            let code = Locale.preferredLanguages.first?.lowercased() ?? ""
            return code.hasPrefix("zh") ? .simplifiedChinese : .english
        case .english, .simplifiedChinese:
            return self
        }
    }

    func text(_ key: String) -> String {
        L10n.text(key, language: resolved)
    }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .system
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

enum L10n {
    static func text(_ key: String, language: AppLanguage) -> String {
        let table = language == .simplifiedChinese ? zhHans : en
        return table[key] ?? en[key] ?? key
    }

    private static let en: [String: String] = [
        "appearance": "Appearance",
        "appearance.system": "Follow System",
        "appearance.light": "Light",
        "appearance.dark": "Dark",
        "theme.title": "Theme and Language",
        "language": "Language",
        "language.system": "Follow System",
        "language.english": "English",
        "language.chinese": "Simplified Chinese",
        "settings.title": "Settings",
        "settings.general": "General",
        "updates.title": "Updates",
        "updates.currentVersion": "Current Version",
        "updates.check": "Check for Updates...",
        "updates.available.title": "A New Version Is Available",
        "updates.available.message": "Current version: %@\nLatest version: %@",
        "updates.current.title": "ReadArc Is Up to Date",
        "updates.current.message": "Current version: %@",
        "updates.noRelease.title": "No Releases Found",
        "updates.noRelease.message": "ReadArc does not have a published GitHub release yet.",
        "updates.failed.title": "Unable to Check for Updates",
        "updates.openReleases": "Open GitHub Releases",
        "updates.later": "Later",
        "updates.ok": "OK",
        "library.title": "Library",
        "library.subtitle": "Recent PDFs and reading sets",
        "library.search": "Search library",
        "library.all": "All",
        "library.quotes": "Quotes",
        "library.specs": "Specs",
        "library.recent": "Recent",
        "library.noRecent": "No recent PDFs",
        "library.noMatches": "No matching PDFs",
        "openPDF": "Open PDF",
        "loadingPDF": "Opening PDF...",
        "clearRecent": "Clear Recent",
        "chat.title": "Chat",
        "chat.subtitle": "Use an agent with this PDF.",
        "chat.context": "Context",
        "chat.attached": "Attached",
        "chat.empty": "Empty",
        "chat.noPDFContext": "Open a PDF to give the agent document context.",
        "chat.pages": "%d pages · current page %d",
        "chat.initial": "Hi, I’m ReadArc. Ask me to summarize, explain, search, or analyze the current PDF.",
        "chat.placeholder": "Ask ReadArc...",
        "chat.backend": "Agent backend: %@",
        "chat.agentUnavailable": "This agent is unavailable on this Mac.",
        "chat.agentRunFailed": "The agent stopped before returning a readable answer.",
        "chat.status.checking": "checking",
        "chat.status.available": "available",
        "chat.status.unavailable": "unavailable",
        "chat.status.running": "runing",
        "chat.prepared": "ReadArc is ready. Next, it will process this PDF and stream the response here.",
        "inspector.title": "Inspector",
        "inspector.subtitle": "Search, outline, notes",
        "drop.title": "Drop PDF to Open",
        "empty.title": "Open a PDF",
        "empty.subtitle": "Choose a local document to start reading."
    ]

    private static let zhHans: [String: String] = [
        "appearance": "外观",
        "appearance.system": "跟随系统",
        "appearance.light": "浅色",
        "appearance.dark": "深色",
        "theme.title": "主题和语言",
        "language": "语言",
        "language.system": "跟随系统",
        "language.english": "英文",
        "language.chinese": "简体中文",
        "settings.title": "设置",
        "settings.general": "通用",
        "updates.title": "更新",
        "updates.currentVersion": "当前版本",
        "updates.check": "检查更新...",
        "updates.available.title": "发现新版本",
        "updates.available.message": "当前版本：%@\n最新版本：%@",
        "updates.current.title": "ReadArc 已是最新版本",
        "updates.current.message": "当前版本：%@",
        "updates.noRelease.title": "暂未找到发布版本",
        "updates.noRelease.message": "ReadArc 目前还没有发布 GitHub Release。",
        "updates.failed.title": "无法检查更新",
        "updates.openReleases": "打开 GitHub Releases",
        "updates.later": "稍后",
        "updates.ok": "好",
        "library.title": "资料库",
        "library.subtitle": "最近 PDF 与阅读集",
        "library.search": "搜索资料库",
        "library.all": "全部",
        "library.quotes": "摘录",
        "library.specs": "规格",
        "library.recent": "最近",
        "library.noRecent": "暂无最近 PDF",
        "library.noMatches": "没有匹配的 PDF",
        "openPDF": "打开 PDF",
        "loadingPDF": "正在打开 PDF...",
        "clearRecent": "清空最近",
        "chat.title": "对话",
        "chat.subtitle": "使用 Agent 阅读当前 PDF。",
        "chat.context": "上下文",
        "chat.attached": "已附加",
        "chat.empty": "空",
        "chat.noPDFContext": "打开 PDF 后，Agent 会获得文档上下文。",
        "chat.pages": "%d 页 · 当前第 %d 页",
        "chat.initial": "你好，我是 ReadArc。可以帮你总结、解释、检索和分析当前 PDF。",
        "chat.placeholder": "询问 ReadArc...",
        "chat.backend": "Agent 后端：%@",
        "chat.agentUnavailable": "当前 Mac 上这个 Agent 不可用。",
        "chat.agentRunFailed": "Agent 未返回可读回复。",
        "chat.status.checking": "检测中",
        "chat.status.available": "可用",
        "chat.status.unavailable": "不可用",
        "chat.status.running": "运行中",
        "chat.prepared": "ReadArc 已准备好处理当前 PDF，并会在这里流式输出回复。",
        "inspector.title": "文档检查",
        "inspector.subtitle": "搜索、大纲、笔记",
        "drop.title": "拖入 PDF 打开",
        "empty.title": "打开 PDF",
        "empty.subtitle": "选择本地文档开始阅读。"
    ]
}

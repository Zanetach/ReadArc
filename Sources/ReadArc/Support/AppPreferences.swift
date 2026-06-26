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
        "permission.fileAccess.title": "Allow ReadArc to open this PDF",
        "permission.fileAccess.message": "macOS may ask whether ReadArc can access the folder that contains this PDF. Choose Allow so ReadArc can read, search, and analyze the document. This reminder appears only once.",
        "permission.fileAccess.continue": "Continue",
        "permission.fileAccess.cancel": "Cancel",
        "github.star": "Star on GitHub",
        "toolbar.previousPage": "Previous Page",
        "toolbar.nextPage": "Next Page",
        "toolbar.zoomOut": "Zoom Out",
        "toolbar.zoomIn": "Zoom In",
        "toolbar.fitPage": "Fit Page",
        "toolbar.actualSize": "Actual Size",
        "toolbar.firstPage": "First Page",
        "toolbar.lastPage": "Last Page",
        "toolbar.search": "Search",
        "toolbar.clearSearch": "Clear Search",
        "toolbar.searchMatchesFormat": "%@ matches",
        "toolbar.previousMatch": "Previous Match",
        "toolbar.nextMatch": "Next Match",
        "toolbar.showPanel": "Show Panel",
        "toolbar.hidePanel": "Hide Panel",
        "toolbar.showChat": "Show Chat",
        "toolbar.more": "More",
        "toolbar.collapseControls": "Collapse Controls",
        "toolbar.expandControls": "Expand Controls",
        "library.title": "Library",
        "library.subtitle": "Recent PDFs and reading sets",
        "library.search": "Search library",
        "library.all": "All",
        "library.quotes": "Quotes",
        "library.specs": "Specs",
        "library.recent": "Recent",
        "library.pinned": "Pinned",
        "library.local": "Local",
        "library.noRecent": "No recent PDFs",
        "library.noMatches": "No matching PDFs",
        "library.removeRecent": "Remove from Recent",
        "thumbnails.title": "Thumbnails",
        "openPDF": "Open PDF",
        "loadingPDF": "Opening PDF...",
        "clearRecent": "Clear Recent",
        "panel.chat": "Chat",
        "panel.focus": "Focus",
        "panel.research": "Research",
        "panel.chat.subtitle": "Ask Codex or Claude Code about the current PDF.",
        "panel.focus.subtitle": "Current page brief, reading state, and notes.",
        "panel.research.subtitle": "Search matches, outline, and source evidence.",
        "panel.focus.current": "Current Focus",
        "panel.focus.summary": "Keep the current page context and notes together.",
        "inspector.search": "Search",
        "inspector.search.summary": "Find exact matches and page-level evidence.",
        "inspector.outline": "Outline",
        "inspector.outline.summary": "Jump through the document structure.",
        "inspector.notes": "Notes",
        "inspector.notes.summary": "Keep page-linked reading notes.",
        "inspector.metric.pages": "pages",
        "inspector.metric.matches": "matches",
        "inspector.metric.outline": "outline",
        "inspector.metric.size": "size",
        "inspector.summary": "Summary",
        "inspector.page": "page %d",
        "inspector.summary.empty.title": "Open a PDF to inspect its structure.",
        "inspector.summary.empty.body": "Summary, outline, file details, and notes will appear here.",
        "inspector.summary.searching.title": "Searching this PDF.",
        "inspector.summary.searching.body": "Indexing text in the background so reading stays responsive.",
        "inspector.summary.ready.title": "Ready for focused reading.",
        "inspector.summary.ready.body": "Use search to build page-linked evidence without leaving the document.",
        "inspector.summary.results.title": "Evidence trail ready.",
        "inspector.summary.results.body": "%d matches are ready for quick navigation.",
        "inspector.summary.results.truncated": "Showing the first %d matches to keep memory usage stable.",
        "inspector.searchMatches": "Search Matches",
        "inspector.search.searching": "Searching in the background...",
        "inspector.search.empty": "Type in the search box to list matches here.",
        "inspector.search.noResults": "No matches for “%@”.",
        "inspector.outline.empty": "This PDF does not include an outline.",
        "inspector.file": "File",
        "inspector.note.placeholder": "Page-linked annotations will arrive in a later update.",
        "chat.title": "Chat",
        "chat.subtitle": "Use an agent with this PDF.",
        "chat.context": "Context",
        "chat.attached": "Attached",
        "chat.empty": "Empty",
        "chat.agentName": "ReadArc Agent",
        "chat.agentOnline": "Online",
        "chat.basedOnPDF": "Based on current PDF · page %d",
        "chat.sources": "Sources",
        "chat.viewAllSources": "View all %d sources",
        "chat.quickActions": "Quick Actions",
        "chat.greeting": "Greeting",
        "chat.action.summaryPage": "Summarize this page",
        "chat.action.keyPoints": "Extract key points",
        "chat.action.mindMap": "Generate mind map",
        "chat.prompt.summaryPage": "Summarize the current PDF page with concise bullets and cite the page number.",
        "chat.prompt.keyPoints": "Extract the key points from the current PDF page and group them by topic.",
        "chat.prompt.mindMap": "Create a compact text mind map for the current PDF page.",
        "chat.noPDFContext": "Open a PDF to give the agent document context.",
        "chat.pages": "%d pages · current page %d",
        "chat.initial": "Hi, I’m ReadArc. Ask me to summarize, explain, search, or analyze the current PDF.",
        "chat.placeholder": "Ask ReadArc...",
        "chat.backend": "Agent backend: %@",
        "chat.agentUnavailable": "This agent is unavailable on this Mac. Install the `%@` CLI and make sure it is on PATH.",
        "chat.agentRunFailed": "The agent stopped before returning a readable answer.",
        "chat.outputTruncated": "Output truncated to keep ReadArc responsive.",
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
        "permission.fileAccess.title": "允许 ReadArc 打开这个 PDF",
        "permission.fileAccess.message": "macOS 可能会询问是否允许 ReadArc 访问这个 PDF 所在的文件夹。请选择“允许”，这样 ReadArc 才能读取、搜索和分析文档。这个提醒只会出现一次。",
        "permission.fileAccess.continue": "继续打开",
        "permission.fileAccess.cancel": "取消",
        "github.star": "Star GitHub",
        "toolbar.previousPage": "上一页",
        "toolbar.nextPage": "下一页",
        "toolbar.zoomOut": "缩小",
        "toolbar.zoomIn": "放大",
        "toolbar.fitPage": "适合窗口",
        "toolbar.actualSize": "实际大小",
        "toolbar.firstPage": "第一页",
        "toolbar.lastPage": "最后一页",
        "toolbar.search": "搜索",
        "toolbar.clearSearch": "清空搜索",
        "toolbar.searchMatchesFormat": "%@ 个匹配",
        "toolbar.previousMatch": "上一个匹配",
        "toolbar.nextMatch": "下一个匹配",
        "toolbar.showPanel": "显示右侧栏",
        "toolbar.hidePanel": "隐藏右侧栏",
        "toolbar.showChat": "显示对话",
        "toolbar.more": "更多",
        "toolbar.collapseControls": "折叠工具栏",
        "toolbar.expandControls": "展开工具栏",
        "library.title": "资料库",
        "library.subtitle": "最近 PDF 与阅读集",
        "library.search": "搜索资料库",
        "library.all": "全部",
        "library.quotes": "摘录",
        "library.specs": "规格",
        "library.recent": "最近",
        "library.pinned": "置顶",
        "library.local": "本地",
        "library.noRecent": "暂无最近 PDF",
        "library.noMatches": "没有匹配的 PDF",
        "library.removeRecent": "从最近中移除",
        "thumbnails.title": "缩略图",
        "openPDF": "打开 PDF",
        "loadingPDF": "正在打开 PDF...",
        "clearRecent": "清空最近",
        "panel.chat": "对话",
        "panel.focus": "专注",
        "panel.research": "研究",
        "panel.chat.subtitle": "向 Codex 或 Claude Code 询问当前 PDF。",
        "panel.focus.subtitle": "当前页摘要、阅读状态和笔记。",
        "panel.research.subtitle": "搜索命中、大纲和来源证据。",
        "panel.focus.current": "当前专注",
        "panel.focus.summary": "把当前页上下文和笔记放在一起。",
        "inspector.search": "搜索",
        "inspector.search.summary": "定位精确匹配和页内证据。",
        "inspector.outline": "大纲",
        "inspector.outline.summary": "按文档结构快速跳转。",
        "inspector.notes": "笔记",
        "inspector.notes.summary": "记录与页面关联的阅读笔记。",
        "inspector.metric.pages": "页数",
        "inspector.metric.matches": "匹配",
        "inspector.metric.outline": "大纲",
        "inspector.metric.size": "大小",
        "inspector.summary": "摘要",
        "inspector.page": "第 %d 页",
        "inspector.summary.empty.title": "打开 PDF 后可查看文档结构。",
        "inspector.summary.empty.body": "摘要、大纲、文件信息和笔记会显示在这里。",
        "inspector.summary.searching.title": "正在搜索当前 PDF。",
        "inspector.summary.searching.body": "正在后台建立文本索引，阅读不会被打断。",
        "inspector.summary.ready.title": "可以开始专注阅读。",
        "inspector.summary.ready.body": "使用搜索生成带页码的证据线索，同时保持 PDF 可见。",
        "inspector.summary.results.title": "证据线索已就绪。",
        "inspector.summary.results.body": "已索引 %d 个匹配，可快速跳转。",
        "inspector.summary.results.truncated": "为保持内存稳定，仅显示前 %d 个匹配。",
        "inspector.searchMatches": "搜索结果",
        "inspector.search.searching": "正在后台搜索...",
        "inspector.search.empty": "在顶部搜索框输入关键词后，这里会显示匹配结果。",
        "inspector.search.noResults": "没有找到“%@”的匹配结果。",
        "inspector.outline.empty": "这个 PDF 没有内置大纲。",
        "inspector.file": "文件",
        "inspector.note.placeholder": "页面关联批注会在后续版本支持。",
        "chat.title": "对话",
        "chat.subtitle": "使用 Agent 阅读当前 PDF。",
        "chat.context": "上下文",
        "chat.attached": "已附加",
        "chat.empty": "空",
        "chat.agentName": "ReadArc Agent",
        "chat.agentOnline": "在线",
        "chat.basedOnPDF": "基于当前 PDF · 第 %d 页",
        "chat.sources": "来源",
        "chat.viewAllSources": "查看全部 %d 个来源",
        "chat.quickActions": "快速操作",
        "chat.greeting": "打招呼",
        "chat.action.summaryPage": "总结本页内容",
        "chat.action.keyPoints": "提取关键要点",
        "chat.action.mindMap": "生成思维导图",
        "chat.prompt.summaryPage": "请总结当前 PDF 页面，用简洁要点输出，并标注页码。",
        "chat.prompt.keyPoints": "请提取当前 PDF 页面的关键要点，并按主题归类。",
        "chat.prompt.mindMap": "请为当前 PDF 页面生成一份紧凑的文本思维导图。",
        "chat.noPDFContext": "打开 PDF 后，Agent 会获得文档上下文。",
        "chat.pages": "%d 页 · 当前第 %d 页",
        "chat.initial": "你好，我是 ReadArc。可以帮你总结、解释、检索和分析当前 PDF。",
        "chat.placeholder": "询问 ReadArc...",
        "chat.backend": "Agent 后端：%@",
        "chat.agentUnavailable": "当前 Mac 上这个 Agent 不可用。请安装 `%@` CLI，并确认它在 PATH 中。",
        "chat.agentRunFailed": "Agent 未返回可读回复。",
        "chat.outputTruncated": "为保持 ReadArc 流畅，已截断过长输出。",
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

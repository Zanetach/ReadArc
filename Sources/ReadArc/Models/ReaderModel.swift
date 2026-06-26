import AppKit
import Combine
import CryptoKit
import Foundation
import PDFKit
import ReadArcCore
import UniformTypeIdentifiers

@MainActor
final class ReaderModel: NSObject, ObservableObject {
    @Published var document: PDFDocument?
    @Published var documentURL: URL?
    @Published var displayTitle = "ReadArc"
    @Published var pageIndex = 0
    @Published var pageCount = 0
    @Published var scaleFactor: CGFloat = 1
    @Published var searchText = "" {
        didSet {
            if searchText != oldValue {
                scheduleSearch()
            }
        }
    }
    @Published var searchResults: [SearchMatch] = []
    @Published var selectedSearchIndex: Int?
    @Published var isSearching = false
    @Published var isSearchTruncated = false
    @Published var isLoadingDocument = false
    @Published var outlineItems: [DocumentOutlineItem] = []
    @Published var pendingCommand: PDFViewCommand?
    @Published var errorMessage: String?
    @Published var isLibraryOverlayVisible = false
    @Published var isSidebarVisible = false
    @Published private(set) var panelState = ReaderPanelState.default
    @Published var selectedChatAgent: ChatAgentProvider = .codexCLI
    @Published var chatMessages: [ChatMessage] = []
    @Published private(set) var libraryFolderURL: URL?

    let recents = RecentDocumentsStore()
    private var loadTask: Task<Void, Never>?
    private var indexTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var pageTextTask: Task<Void, Never>?
    private var activeLoadID: UUID?
    private var documentBookmarkData: Data?
    private var activeDocumentURL: URL?
    private var activeDocumentBookmarkData: Data?
    private var libraryFolderBookmarkData: Data?
    private var cachedPageTexts: [DocumentPageText] = []
    private let permissionPrimerDefaults = UserDefaults.standard
    nonisolated private static let maxSearchResultCount = 500
    nonisolated private static let minimumSearchLength = 2
    nonisolated private static let maxCachedPageTextPages = 120
    nonisolated private static let maxCachedPageTextCharacters = 220_000
    nonisolated private static let maxStoredChatMessages = 80
    nonisolated private static let cachedPageTextLimit = 4_000
    nonisolated private static let maxSearchPageTextCharacters = 280_000
    nonisolated private static let maxSearchDurationSeconds: TimeInterval = 12
    nonisolated private static let fileAccessPrimerSeenKey = "readArcFileAccessPrimerSeen"
    nonisolated private static let libraryFolderPromptSeenKey = "readArcLibraryFolderPromptSeen"
    nonisolated private static let libraryFolderURLKey = "readArcLibraryFolderURL"
    nonisolated private static let libraryFolderBookmarkKey = "readArcLibraryFolderBookmark"

    var hasDocument: Bool {
        document != nil
    }

    var isInspectorVisible: Bool {
        panelState.isInspectorVisible
    }

    var rightPanelMode: RightPanelMode {
        panelState.rightPanelMode
    }

    var inspectorTab: InspectorTab {
        panelState.inspectorTab
    }

    var readerMode: ReaderMode {
        panelState.readerMode
    }

    var pageLabel: String {
        guard pageCount > 0 else { return "-" }
        return "\(pageIndex + 1) / \(pageCount)"
    }

    var scaleLabel: String {
        "\(Int((scaleFactor * 100).rounded()))%"
    }

    var searchLabel: String {
        if isSearching {
            return "..."
        }

        guard let selectedSearchIndex, !searchResults.isEmpty else {
            if searchResults.isEmpty {
                return "0"
            }
            return isSearchTruncated ? "\(searchResults.count)+" : "\(searchResults.count)"
        }
        return "\(selectedSearchIndex + 1) / \(searchResults.count)"
    }

    var selectedSearchResult: SearchMatch? {
        guard let selectedSearchIndex,
              searchResults.indices.contains(selectedSearchIndex) else {
            return nil
        }
        return searchResults[selectedSearchIndex]
    }

    var documentTitle: String {
        displayTitle
    }

    var documentLocation: String {
        documentURL?.deletingLastPathComponent().path ?? ""
    }

    var fileSizeLabel: String {
        guard let documentURL,
              let values = try? documentURL.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else {
            return "-"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    var searchMatches: [SearchMatch] {
        searchResults
    }

    var libraryFolderDisplayName: String {
        libraryFolderURL?.lastPathComponent ?? currentAppLanguage.text("library.folder.unset")
    }

    override init() {
        super.init()
        restoreLibraryFolder()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenFileRequest(_:)),
            name: .readArcOpenFileRequested,
            object: nil
        )
        openPendingExternalFiles()
    }

    deinit {
        loadTask?.cancel()
        indexTask?.cancel()
        searchTask?.cancel()
        pageTextTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func openDocument() {
        promptForLibraryFolderIfNeeded()

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a PDF document to read."
        panel.directoryURL = libraryFolderURL

        if panel.runModal() == .OK, let url = panel.url {
            openExternalFile(url)
        }
    }

    func openPDF(url: URL, bookmarkData: Data? = nil) {
        guard fileExistsForReading(url: url, bookmarkData: bookmarkData) else {
            handleMissingPDF(at: url)
            return
        }

        guard isURLInsideLibrary(url) || confirmFileAccessPrimerIfNeeded(for: url) else {
            return
        }

        load(url: url, bookmarkData: bookmarkData)
    }

    func configureLibraryFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = currentAppLanguage.text("library.folder.panel.message")
        panel.prompt = currentAppLanguage.text("library.folder.panel.choose")
        panel.directoryURL = libraryFolderURL ?? defaultLibraryParentURL

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        setLibraryFolder(url)
    }

    private func confirmFileAccessPrimerIfNeeded(for url: URL) -> Bool {
        guard url.isFileURL,
              !permissionPrimerDefaults.bool(forKey: Self.fileAccessPrimerSeenKey) else {
            return true
        }

        let language = currentAppLanguage
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.text("permission.fileAccess.title", language: language)
        alert.informativeText = L10n.text("permission.fileAccess.message", language: language)
        alert.addButton(withTitle: L10n.text("permission.fileAccess.continue", language: language))
        alert.addButton(withTitle: L10n.text("permission.fileAccess.cancel", language: language))
        if let icon = Self.permissionAlertIcon {
            alert.icon = icon
        }

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return false
        }

        permissionPrimerDefaults.set(true, forKey: Self.fileAccessPrimerSeenKey)
        return true
    }

    private func promptForLibraryFolderIfNeeded() {
        guard currentLibraryFolderAccess() == nil,
              !permissionPrimerDefaults.bool(forKey: Self.libraryFolderPromptSeenKey) else {
            return
        }

        let language = currentAppLanguage
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.text("permission.fileAccess.title", language: language)
        alert.informativeText = L10n.text("permission.fileAccess.message", language: language)
        alert.addButton(withTitle: L10n.text("permission.fileAccess.continue", language: language))
        alert.addButton(withTitle: L10n.text("permission.fileAccess.cancel", language: language))
        if let icon = Self.permissionAlertIcon {
            alert.icon = icon
        }

        permissionPrimerDefaults.set(true, forKey: Self.libraryFolderPromptSeenKey)

        if alert.runModal() == .alertFirstButtonReturn {
            configureLibraryFolder()
        }
    }

    private var defaultLibraryParentURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private func restoreLibraryFolder() {
        libraryFolderURL = permissionPrimerDefaults
            .string(forKey: Self.libraryFolderURLKey)
            .map(URL.init(fileURLWithPath:))
        libraryFolderBookmarkData = permissionPrimerDefaults.data(forKey: Self.libraryFolderBookmarkKey)

        if let access = currentLibraryFolderAccess() {
            libraryFolderURL = access.url
            libraryFolderBookmarkData = access.bookmarkData
        }
    }

    private func setLibraryFolder(_ url: URL) {
        let bookmarkData = Self.makeSecurityScopedBookmark(for: url)
        libraryFolderURL = url
        libraryFolderBookmarkData = bookmarkData
        permissionPrimerDefaults.set(url.path, forKey: Self.libraryFolderURLKey)
        if let bookmarkData {
            permissionPrimerDefaults.set(bookmarkData, forKey: Self.libraryFolderBookmarkKey)
        } else {
            permissionPrimerDefaults.removeObject(forKey: Self.libraryFolderBookmarkKey)
        }
    }

    private func currentLibraryFolderAccess() -> (url: URL, bookmarkData: Data?)? {
        if let bookmarkData = libraryFolderBookmarkData,
           let resolvedURL = Self.resolvedSecurityScopedURL(bookmarkData: bookmarkData) {
            if libraryFolderURL != resolvedURL {
                libraryFolderURL = resolvedURL
                permissionPrimerDefaults.set(resolvedURL.path, forKey: Self.libraryFolderURLKey)
            }
            return (resolvedURL, bookmarkData)
        }

        guard let libraryFolderURL else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: libraryFolderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        return (libraryFolderURL, nil)
    }

    private func isURLInsideLibrary(_ url: URL) -> Bool {
        guard let libraryAccess = currentLibraryFolderAccess() else {
            return false
        }
        return Self.isFile(url, containedIn: libraryAccess.url)
    }

    private var currentAppLanguage: AppLanguage {
        let storedLanguage = permissionPrimerDefaults.string(forKey: "appLanguage")
        return (storedLanguage.flatMap(AppLanguage.init(rawValue:)) ?? .system).resolved
    }

    @MainActor
    private static var permissionAlertIcon: NSImage? {
        if let icon = NSImage(named: "readarc-logo") {
            return icon
        }

        guard let iconURL = Bundle.main.url(forResource: "readarc-logo", withExtension: "png") else {
            return NSApp.applicationIconImage
        }
        return NSImage(contentsOf: iconURL) ?? NSApp.applicationIconImage
    }

    private func load(url: URL, bookmarkData: Data? = nil) {
        guard url.pathExtension.lowercased() == "pdf" else {
            errorMessage = currentAppLanguage.text("openPDF.error.notPDF")
            return
        }

        guard fileExistsForReading(url: url, bookmarkData: bookmarkData) else {
            handleMissingPDF(at: url)
            return
        }

        loadTask?.cancel()
        indexTask?.cancel()
        searchTask?.cancel()
        pageTextTask?.cancel()

        let loadID = UUID()
        activeLoadID = loadID
        errorMessage = nil
        isLoadingDocument = true
        isSearching = false
        isSearchTruncated = false
        isLibraryOverlayVisible = false
        isSidebarVisible = false
        document = nil
        documentURL = url
        displayTitle = url.deletingPathExtension().lastPathComponent
        pageIndex = 0
        pageCount = 0
        scaleFactor = 1
        searchResults = []
        selectedSearchIndex = nil
        outlineItems = []
        documentBookmarkData = bookmarkData
        activeDocumentURL = nil
        activeDocumentBookmarkData = nil
        cachedPageTexts = []
        setPanelState(
            isInspectorVisible: false,
            rightPanelMode: .research,
            inspectorTab: .search,
            readerMode: .nativePro
        )

        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            let payload = Self.loadPDFPayload(url: url, bookmarkData: bookmarkData)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self,
                      self.activeLoadID == loadID,
                      !Task.isCancelled else {
                    return
                }

                guard let payload else {
                    self.isLoadingDocument = false
                    self.errorMessage = self.currentAppLanguage.text("openPDF.error.failed")
                    return
                }

                self.document = payload.document
                self.documentURL = url
                self.displayTitle = payload.displayTitle
                self.documentBookmarkData = bookmarkData
                self.activeDocumentURL = payload.processingURL
                self.activeDocumentBookmarkData = payload.processingBookmarkData
                self.pageIndex = 0
                self.pageCount = payload.pageCount
                self.scaleFactor = 1
                self.outlineItems = []
                self.cachedPageTexts = []
                self.isLibraryOverlayVisible = false
                self.isSidebarVisible = false
                self.setPanelState(
                    isInspectorVisible: false,
                    rightPanelMode: .research,
                    inspectorTab: .search,
                    readerMode: .nativePro
                )
                self.isLoadingDocument = false
                self.recents.add(url: url, title: payload.displayTitle, bookmarkData: bookmarkData)
                self.scheduleSearch()
                self.scheduleDocumentIndexing(
                    loadID: loadID,
                    originalURL: url,
                    originalBookmarkData: bookmarkData,
                    processingURL: payload.processingURL,
                    processingBookmarkData: payload.processingBookmarkData
                )
                self.loadTask = nil
            }
        }
    }

    func openRecent(_ recent: RecentDocument) {
        openPDF(url: recent.url, bookmarkData: recent.bookmarkData)
    }

    func openExternalFile(_ url: URL) {
        let sourceBookmarkData = Self.makeSecurityScopedBookmark(for: url)
        guard fileExistsForReading(url: url, bookmarkData: sourceBookmarkData) else {
            handleMissingPDF(at: url)
            return
        }

        promptForLibraryFolderIfNeeded()

        if let libraryDocument = importPDFIntoLibraryIfPossible(from: url, bookmarkData: sourceBookmarkData) {
            load(url: libraryDocument.url, bookmarkData: libraryDocument.bookmarkData)
        } else {
            load(url: url, bookmarkData: sourceBookmarkData)
        }
    }

    func removeRecent(_ recent: RecentDocument) {
        recents.remove(recent)
    }

    func clearRecents() {
        recents.clear()
    }

    private func importPDFIntoLibraryIfPossible(from url: URL, bookmarkData: Data?) -> (url: URL, bookmarkData: Data?)? {
        guard let libraryAccess = currentLibraryFolderAccess() else {
            return nil
        }

        return Self.withSecurityScopedFileAccess(url: url, bookmarkData: bookmarkData) { scopedSourceURL in
            Self.withSecurityScopedFileAccess(url: libraryAccess.url, bookmarkData: libraryAccess.bookmarkData) { scopedLibraryURL in
                guard scopedSourceURL.pathExtension.lowercased() == "pdf" else {
                    return nil
                }

                let importedURL: URL
                if Self.isFile(scopedSourceURL, containedIn: scopedLibraryURL) {
                    importedURL = scopedSourceURL
                } else {
                    guard let copiedURL = Self.importPDFForReading(from: scopedSourceURL, into: scopedLibraryURL) else {
                        return nil
                    }
                    importedURL = copiedURL
                }

                return (
                    url: importedURL,
                    bookmarkData: Self.makeSecurityScopedBookmark(for: importedURL)
                )
            }
        }
    }

    func closeDocument() {
        loadTask?.cancel()
        indexTask?.cancel()
        searchTask?.cancel()
        pageTextTask?.cancel()
        activeLoadID = nil
        document = nil
        documentURL = nil
        displayTitle = "ReadArc"
        pageIndex = 0
        pageCount = 0
        scaleFactor = 1
        searchText = ""
        searchResults = []
        selectedSearchIndex = nil
        isLoadingDocument = false
        isSearching = false
        isSearchTruncated = false
        outlineItems = []
        documentBookmarkData = nil
        activeDocumentURL = nil
        activeDocumentBookmarkData = nil
        cachedPageTexts = []
        indexTask = nil
        pageTextTask = nil
        setPanelState(
            isInspectorVisible: false,
            rightPanelMode: .research,
            inspectorTab: .search,
            readerMode: .nativePro
        )
    }

    func revealDocumentInFinder() {
        guard let documentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([documentURL])
    }

    func showLibrary() {
        setIfChanged(\.isLibraryOverlayVisible, to: !isLibraryOverlayVisible)
        setIfChanged(\.isSidebarVisible, to: true)
        setPanelState(readerMode: .nativePro)
    }

    func showThumbnails() {
        setIfChanged(\.isLibraryOverlayVisible, to: false)
        setIfChanged(\.isSidebarVisible, to: true)
        setPanelState(readerMode: .nativePro)
    }

    func toggleThumbnails() {
        if hasDocument, isSidebarVisible, !isLibraryOverlayVisible {
            setIfChanged(\.isSidebarVisible, to: false)
            setPanelState(readerMode: .nativePro)
        } else {
            showThumbnails()
        }
    }

    func showSidebar() {
        setIfChanged(\.isSidebarVisible, to: true)
        setIfChanged(\.isLibraryOverlayVisible, to: false)
        setPanelState(readerMode: .nativePro)
    }

    func toggleSidebar() {
        setIfChanged(\.isSidebarVisible, to: !isSidebarVisible)
        setIfChanged(\.isLibraryOverlayVisible, to: false)
        setPanelState(readerMode: .nativePro)
    }

    func showInspector(tab: InspectorTab? = nil) {
        if tab == .notes {
            showFocus()
        } else {
            showResearch(tab: tab)
        }
    }

    func showRightPanel(_ mode: RightPanelMode) {
        switch mode {
        case .chat:
            showChat()
        case .focus:
            showFocus()
        case .research:
            showResearch()
        }
    }

    func showFocus() {
        setIfChanged(\.isLibraryOverlayVisible, to: false)
        setPanelState(
            isInspectorVisible: true,
            rightPanelMode: .focus,
            inspectorTab: .notes,
            readerMode: .focus
        )
    }

    func showResearch(tab: InspectorTab? = nil) {
        setIfChanged(\.isLibraryOverlayVisible, to: false)
        let nextTab: InspectorTab
        if let tab {
            nextTab = tab
        } else if inspectorTab == .notes {
            nextTab = .search
        } else {
            nextTab = inspectorTab
        }
        setPanelState(
            isInspectorVisible: true,
            rightPanelMode: .research,
            inspectorTab: nextTab,
            readerMode: .research
        )
    }

    func showChat() {
        setIfChanged(\.isLibraryOverlayVisible, to: false)
        setPanelState(
            isInspectorVisible: true,
            rightPanelMode: .chat
        )
    }

    func toggleChat() {
        if isInspectorVisible && rightPanelMode == .chat {
            setPanelState(isInspectorVisible: false)
        } else {
            showChat()
        }
    }

    func agentPDFContext() -> AgentPDFContext? {
        guard let document, hasDocument else { return nil }

        let currentPageNumber = pageIndex + 1
        let currentPageText = cachedText(at: pageIndex) ?? ""
        let nearbyPageExcerpts = [pageIndex - 1, pageIndex + 1].compactMap { index -> AgentPDFPageExcerpt? in
            guard index >= 0,
                  index < document.pageCount,
                  let text = cachedText(at: index),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return AgentPDFPageExcerpt(pageNumber: index + 1, text: text)
        }

        let pageMapExcerpts = cachedPageTexts.map {
            AgentPDFPageExcerpt(pageNumber: $0.pageNumber, text: $0.text)
        }

        return AgentPDFContext(
            title: documentTitle,
            pageCount: pageCount,
            currentPageNumber: currentPageNumber,
            currentPageText: currentPageText,
            nearbyPageExcerpts: nearbyPageExcerpts,
            outlineItems: outlineItems.prefix(12).map(\.title),
            documentPageExcerpts: pageMapExcerpts
        )
    }

    private func cachedText(at pageIndex: Int) -> String? {
        cachedPageTexts.first { $0.pageIndex == pageIndex }?.text
    }

    func pruneChatHistory() {
        guard chatMessages.count > Self.maxStoredChatMessages else { return }
        let activeIDs = Set(chatMessages.filter(\.isStreaming).map(\.id))
        while chatMessages.count > Self.maxStoredChatMessages,
              let removableIndex = chatMessages.firstIndex(where: { !activeIDs.contains($0.id) }) {
            chatMessages.remove(at: removableIndex)
        }
    }

    func toggleInspectorPanel() {
        if isInspectorVisible {
            setPanelState(isInspectorVisible: false)
        } else {
            showRightPanel(rightPanelMode)
        }
    }

    private func setPanelState(
        isInspectorVisible: Bool? = nil,
        rightPanelMode: RightPanelMode? = nil,
        inspectorTab: InspectorTab? = nil,
        readerMode: ReaderMode? = nil
    ) {
        let nextState = panelState.updating(
            isInspectorVisible: isInspectorVisible,
            rightPanelMode: rightPanelMode,
            inspectorTab: inspectorTab,
            readerMode: readerMode
        )

        guard panelState != nextState else {
            return
        }

        panelState = nextState
    }

    private func setIfChanged<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<ReaderModel, Value>, to value: Value) {
        guard self[keyPath: keyPath] != value else { return }
        self[keyPath: keyPath] = value
    }

    func send(_ action: PDFViewAction) {
        pendingCommand = PDFViewCommand(action: action)
    }

    func selectNextSearchResult() {
        guard !searchResults.isEmpty else { return }
        selectedSearchIndex = ((selectedSearchIndex ?? -1) + 1) % searchResults.count
        navigateToSelectedSearchResult()
    }

    func selectPreviousSearchResult() {
        guard !searchResults.isEmpty else { return }
        let current = selectedSearchIndex ?? searchResults.count
        selectedSearchIndex = (current - 1 + searchResults.count) % searchResults.count
        navigateToSelectedSearchResult()
    }

    func selectSearchResult(at index: Int) {
        guard searchResults.indices.contains(index) else { return }
        selectedSearchIndex = index
        navigateToSelectedSearchResult()
    }

    func goToOutlineItem(_ item: DocumentOutlineItem) {
        guard let pageIndex = item.pageIndex else { return }
        send(.goToPage(pageIndex))
    }

    func syncFromPDFView(pageIndex: Int, pageCount: Int, scaleFactor: CGFloat) {
        let nextPageIndex = max(0, pageIndex)
        let nextPageCount = max(0, pageCount)
        let nextScaleFactor = scaleFactor

        if self.pageIndex != nextPageIndex {
            self.pageIndex = nextPageIndex
            schedulePageTextCache(around: nextPageIndex)
        }
        if self.pageCount != nextPageCount {
            self.pageCount = nextPageCount
        }
        if abs(self.scaleFactor - nextScaleFactor) > 0.005 {
            self.scaleFactor = nextScaleFactor
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= Self.minimumSearchLength,
              let documentURL,
              let activeDocumentURL else {
            searchResults = []
            selectedSearchIndex = nil
            isSearching = false
            isSearchTruncated = false
            return
        }

        searchResults = []
        selectedSearchIndex = nil
        isSearching = true
        isSearchTruncated = false

        let limit = Self.maxSearchResultCount
        let bookmarkData = activeDocumentBookmarkData
        searchTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            let output = Self.searchPDF(
                url: activeDocumentURL,
                bookmarkData: bookmarkData,
                query: trimmedQuery,
                limit: limit
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self,
                      self.documentURL == documentURL,
                      self.activeDocumentURL == activeDocumentURL,
                      self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedQuery else {
                    return
                }

                self.searchResults = output.results
                self.selectedSearchIndex = nil
                self.isSearchTruncated = output.truncated
                self.isSearching = false
                self.searchTask = nil
            }
        }
    }

    private func navigateToSelectedSearchResult() {
        guard let selectedSearchResult else { return }
        send(
            .goToSearchMatch(
                pageIndex: selectedSearchResult.pageIndex,
                location: selectedSearchResult.matchLocation,
                length: selectedSearchResult.matchLength
            )
        )
    }

    private func scheduleDocumentIndexing(
        loadID: UUID,
        originalURL: URL,
        originalBookmarkData: Data?,
        processingURL: URL,
        processingBookmarkData: Data?
    ) {
        indexTask?.cancel()
        let sourceURL = originalURL
        let activeURL = processingURL
        indexTask = Task.detached(priority: .utility) { [weak self] in
            let payload = Self.buildPDFIndexPayload(url: activeURL, bookmarkData: processingBookmarkData)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self,
                      self.activeLoadID == loadID,
                      self.documentURL == sourceURL,
                      self.activeDocumentURL == activeURL,
                      !Task.isCancelled else {
                    return
                }

                if let payload {
                    self.displayTitle = payload.displayTitle
                    self.outlineItems = payload.outlineItems
                    self.mergeCachedPageTexts(payload.pageTexts)
                }

                self.schedulePageTextCache(around: self.pageIndex)
                self.indexTask = nil
            }
        }
    }

    nonisolated private static func loadPDFPayload(url: URL, bookmarkData: Data?) -> LoadedPDFPayload? {
        withSecurityScopedFileAccess(url: url, bookmarkData: bookmarkData) { scopedURL in
            autoreleasepool {
                let processingURL = importPDFForReading(from: scopedURL) ?? scopedURL
                let processingBookmarkData = processingURL == scopedURL ? bookmarkData : nil
                guard let document = PDFDocument(url: processingURL) else { return nil }
                return LoadedPDFPayload(
                    document: document,
                    displayTitle: resolvedFastDocumentTitle(for: document, url: scopedURL),
                    pageCount: document.pageCount,
                    processingURL: processingURL,
                    processingBookmarkData: processingBookmarkData
                )
            }
        }
    }

    nonisolated private static func importPDFForReading(from sourceURL: URL, into directoryURL: URL? = nil) -> URL? {
        guard sourceURL.isFileURL,
              let destinationURL = importedPDFURL(for: sourceURL, in: directoryURL) else {
            return nil
        }

        let fileManager = FileManager.default
        let directoryURL = destinationURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            if fileManager.fileExists(atPath: destinationURL.path) {
                let values = try? destinationURL.resourceValues(forKeys: [.fileSizeKey])
                if (values?.fileSize ?? 0) > 0 {
                    return destinationURL
                }
                try? fileManager.removeItem(at: destinationURL)
            }

            let temporaryURL = directoryURL.appendingPathComponent("\(UUID().uuidString).tmp")
            try? fileManager.removeItem(at: temporaryURL)
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }

    nonisolated private static func importedPDFURL(for sourceURL: URL, in directoryURL: URL? = nil) -> URL? {
        let destinationDirectory: URL
        if let directoryURL {
            destinationDirectory = directoryURL
        } else {
            guard let supportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                return nil
            }

            destinationDirectory = supportURL
                .appendingPathComponent("ReadArc", isDirectory: true)
                .appendingPathComponent("ImportedPDFs", isDirectory: true)
        }

        let baseName = sanitizedImportFileName(sourceURL.deletingPathExtension().lastPathComponent)
        let fingerprint = importFingerprint(for: sourceURL)
        return destinationDirectory.appendingPathComponent("\(baseName)-\(fingerprint).pdf")
    }

    nonisolated private static func sanitizedImportFileName(_ name: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_")
        let sanitized = name.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "-" }
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))

        let fallback = sanitized.isEmpty ? "document" : sanitized
        return String(fallback.prefix(64))
    }

    nonisolated private static func importFingerprint(for sourceURL: URL) -> String {
        let values = try? sourceURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = values?.fileSize ?? -1
        let modifiedAt = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let rawFingerprint = "\(sourceURL.path)|\(size)|\(modifiedAt)"
        return String(sha256Hex(rawFingerprint).prefix(16))
    }

    nonisolated private static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func buildPDFIndexPayload(url: URL, bookmarkData: Data?) -> PDFIndexPayload? {
        withSecurityScopedFileAccess(url: url, bookmarkData: bookmarkData) { scopedURL in
            autoreleasepool {
                guard let document = PDFDocument(url: scopedURL) else { return nil }
                return PDFIndexPayload(
                    displayTitle: resolvedDocumentTitle(for: document, url: scopedURL),
                    outlineItems: buildOutlineItems(for: document),
                    pageTexts: buildPageTexts(for: document)
                )
            }
        }
    }

    nonisolated private static func buildPageTexts(for document: PDFDocument) -> [DocumentPageText] {
        var totalCharacters = 0
        var output: [DocumentPageText] = []

        for pageIndex in sampledPageIndexes(pageCount: document.pageCount, limit: maxCachedPageTextPages) {
            guard totalCharacters < maxCachedPageTextCharacters else { break }
            let text = autoreleasepool {
                document.page(at: pageIndex)?.string ?? ""
            }
            let bounded = boundedPageText(text)
            totalCharacters += bounded.count
            output.append(
                DocumentPageText(
                    pageIndex: pageIndex,
                    text: bounded
                )
            )
        }

        return output
    }

    nonisolated private static func resolvedFastDocumentTitle(
        for document: PDFDocument,
        url: URL
    ) -> String {
        let fallback = normalizedTitle(url.deletingPathExtension().lastPathComponent)
        if let metadataTitle = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
           let title = cleanedDocumentTitle(metadataTitle, fallback: fallback) {
            return title
        }

        return fallback.isEmpty ? url.lastPathComponent : fallback
    }

    nonisolated private static func resolvedDocumentTitle(
        for document: PDFDocument,
        url: URL
    ) -> String {
        let fallback = normalizedTitle(url.deletingPathExtension().lastPathComponent)
        if let metadataTitle = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
           let title = cleanedDocumentTitle(metadataTitle, fallback: fallback) {
            return title
        }

        if let firstPageText = document.page(at: 0)?.string,
           let contentTitle = inferredTitle(from: firstPageText, fallback: fallback) {
            return contentTitle
        }

        return fallback.isEmpty ? url.lastPathComponent : fallback
    }

    nonisolated private static func cleanedDocumentTitle(_ rawTitle: String, fallback: String) -> String? {
        let title = normalizedTitle(rawTitle)
        guard isUsableTitle(title) else { return nil }

        let lowercased = title.lowercased()
        if lowercased.hasSuffix(".pdf")
            || lowercased.hasSuffix(".doc")
            || lowercased.hasSuffix(".docx")
            || lowercased.hasPrefix("microsoft word -") {
            return nil
        }

        if title.caseInsensitiveCompare(fallback) == .orderedSame {
            return title
        }

        return title
    }

    nonisolated private static func inferredTitle(from pageText: String, fallback: String) -> String? {
        let lines = pageText
            .components(separatedBy: .newlines)
            .map(normalizedTitle)
            .filter { isUsableTitle($0) }
            .prefix(36)

        var bestCandidate: (title: String, score: Int)?
        let indexedLines = Array(lines.enumerated())

        for (index, line) in indexedLines {
            updateBestTitle(line, index: index, fallback: fallback, best: &bestCandidate)

            if index + 1 < indexedLines.count {
                let nextLine = indexedLines[index + 1].element
                let combined = normalizedTitle("\(line) \(nextLine)")
                updateBestTitle(combined, index: index, fallback: fallback, best: &bestCandidate)
            }
        }

        return bestCandidate?.title
    }

    nonisolated private static func updateBestTitle(
        _ candidate: String,
        index: Int,
        fallback: String,
        best: inout (title: String, score: Int)?
    ) {
        let score = titleScore(candidate, index: index, fallback: fallback)
        guard score > 0 else { return }
        if best == nil || score > best!.score {
            best = (candidate, score)
        }
    }

    nonisolated private static func titleScore(_ title: String, index: Int, fallback: String) -> Int {
        guard isUsableTitle(title), !isMetadataLabel(title) else { return 0 }

        var score = max(0, 80 - index * 3)
        let characterCount = title.count

        if characterCount >= 8 && characterCount <= 80 {
            score += 24
        } else if characterCount > 110 {
            score -= 36
        }

        if containsLetter(title) {
            score += 12
        }
        if title.contains(" ") {
            score += 8
        }
        if title.range(of: #"(流程|方案|报告|指南|手册|白皮书|overview|report|guide|manual)"#, options: [.regularExpression, .caseInsensitive]) != nil {
            score += 18
        }
        if title.lowercased().contains("client onboarding") {
            score -= 24
        }
        if title.range(of: #"[。！？.!?]{2,}|[:：]$"#, options: .regularExpression) != nil {
            score -= 18
        }
        if title.caseInsensitiveCompare(fallback) == .orderedSame {
            score -= 6
        }

        return score
    }

    nonisolated private static func isMetadataLabel(_ title: String) -> Bool {
        let lowercased = title.lowercased()
        let blockedPrefixes = [
            "version",
            "release date",
            "published",
            "client onboarding",
            "onboarding ·",
            "page "
        ]
        if blockedPrefixes.contains(where: { lowercased.hasPrefix($0) }) {
            return true
        }

        let blockedExact = [
            "版本",
            "发布日期",
            "适用",
            "目录",
            "摘要",
            "table of contents"
        ]
        return blockedExact.contains(title)
    }

    nonisolated private static func isUsableTitle(_ title: String) -> Bool {
        guard title.count >= 2, title.count <= 140 else { return false }
        let lowercased = title.lowercased()
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return false
        }
        if title.range(of: #"^\d+([./-]\d+)*$"#, options: .regularExpression) != nil {
            return false
        }
        return containsLetter(title)
    }

    nonisolated private static func containsLetter(_ title: String) -> Bool {
        title.unicodeScalars.contains { scalar in
            CharacterSet.letters.contains(scalar)
        }
    }

    nonisolated private static func normalizedTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func sampledPageIndexes(pageCount: Int, limit: Int) -> [Int] {
        guard pageCount > 0, limit > 0 else { return [] }
        guard pageCount > limit else { return Array(0..<pageCount) }

        let step = Double(pageCount - 1) / Double(limit - 1)
        var seen = Set<Int>()
        return (0..<limit).compactMap { offset in
            let index = min(pageCount - 1, Int((Double(offset) * step).rounded()))
            return seen.insert(index).inserted ? index : nil
        }
    }

    nonisolated private static func makeSecurityScopedBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    nonisolated private static func resolvedSecurityScopedURL(bookmarkData: Data) -> URL? {
        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), !isStale else {
            return nil
        }
        return resolvedURL
    }

    nonisolated private static func isFile(_ fileURL: URL, containedIn directoryURL: URL) -> Bool {
        let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
        let directoryPath = directoryURL.standardizedFileURL.resolvingSymlinksInPath().path
        return filePath == directoryPath || filePath.hasPrefix(directoryPath + "/")
    }

    nonisolated private static func withSecurityScopedFileAccess<T>(
        url: URL,
        bookmarkData: Data?,
        _ work: (URL) -> T
    ) -> T {
        var scopedURL = url

        if let bookmarkData {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale {
                scopedURL = resolvedURL
            }
        }

        let didStartAccessing = scopedURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                scopedURL.stopAccessingSecurityScopedResource()
            }
        }

        return work(scopedURL)
    }

    private func schedulePageTextCache(around pageIndex: Int) {
        guard let activeDocumentURL else { return }
        let candidateIndexes = [pageIndex - 1, pageIndex, pageIndex + 1]
            .filter { $0 >= 0 && $0 < pageCount && cachedText(at: $0) == nil }
        guard !candidateIndexes.isEmpty else { return }

        pageTextTask?.cancel()
        let activeURL = activeDocumentURL
        let bookmarkData = activeDocumentBookmarkData
        pageTextTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }

            let pageTexts = Self.extractPageTexts(url: activeURL, bookmarkData: bookmarkData, pageIndexes: candidateIndexes)
            guard !Task.isCancelled, !pageTexts.isEmpty else { return }

            await MainActor.run {
                guard let self,
                      self.activeDocumentURL == activeURL,
                      !Task.isCancelled else {
                    return
                }
                self.mergeCachedPageTexts(pageTexts)
                self.pageTextTask = nil
            }
        }
    }

    nonisolated private static func extractPageTexts(url: URL, bookmarkData: Data?, pageIndexes: [Int]) -> [DocumentPageText] {
        withSecurityScopedFileAccess(url: url, bookmarkData: bookmarkData) { scopedURL in
            autoreleasepool {
                guard let document = PDFDocument(url: scopedURL) else { return [] }
                return pageIndexes.compactMap { pageIndex in
                    guard pageIndex >= 0, pageIndex < document.pageCount else { return nil }
                    let text = document.page(at: pageIndex)?.string ?? ""
                    return DocumentPageText(pageIndex: pageIndex, text: boundedPageText(text))
                }
            }
        }
    }

    private func mergeCachedPageTexts(_ pageTexts: [DocumentPageText]) {
        var byPageIndex = Dictionary(uniqueKeysWithValues: cachedPageTexts.map { ($0.pageIndex, $0) })
        for pageText in pageTexts {
            byPageIndex[pageText.pageIndex] = pageText
        }

        cachedPageTexts = byPageIndex.values
            .sorted { $0.pageIndex < $1.pageIndex }
        trimCachedPageTexts()
    }

    private func trimCachedPageTexts() {
        guard cachedPageTexts.count > Self.maxCachedPageTextPages
                || cachedPageTexts.reduce(0, { $0 + $1.text.count }) > Self.maxCachedPageTextCharacters else {
            return
        }

        var trimmed: [DocumentPageText] = []
        var totalCharacters = 0
        let preferred = cachedPageTexts.sorted { lhs, rhs in
            abs(lhs.pageIndex - pageIndex) < abs(rhs.pageIndex - pageIndex)
        }

        for pageText in preferred {
            guard trimmed.count < Self.maxCachedPageTextPages,
                  totalCharacters + pageText.text.count <= Self.maxCachedPageTextCharacters else {
                continue
            }
            trimmed.append(pageText)
            totalCharacters += pageText.text.count
        }

        cachedPageTexts = trimmed.sorted { $0.pageIndex < $1.pageIndex }
    }

    nonisolated private static func boundedPageText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > cachedPageTextLimit else {
            return normalized
        }

        let end = normalized.index(normalized.startIndex, offsetBy: cachedPageTextLimit)
        return String(normalized[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    nonisolated private static func buildOutlineItems(for document: PDFDocument) -> [DocumentOutlineItem] {
        guard let outlineRoot = document.outlineRoot else { return [] }
        var items: [DocumentOutlineItem] = []
        collectOutlineItems(from: outlineRoot, document: document, depth: 0, into: &items)
        return Array(items.prefix(80))
    }

    nonisolated private static func collectOutlineItems(
        from outline: PDFOutline,
        document: PDFDocument,
        depth: Int,
        into items: inout [DocumentOutlineItem]
    ) {
        for index in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: index) else { continue }
            let pageIndex = child.destination?.page.flatMap { page in
                document.index(for: page)
            }

            items.append(
                DocumentOutlineItem(
                    id: "\(depth)-\(index)-\(child.label ?? "Outline")",
                    title: child.label ?? "Untitled",
                    pageIndex: pageIndex,
                    depth: depth
                )
            )

            if depth < 2 {
                collectOutlineItems(from: child, document: document, depth: depth + 1, into: &items)
            }
        }
    }

    nonisolated private static func searchPDF(url: URL, bookmarkData: Data?, query: String, limit: Int) -> SearchOutput {
        withSecurityScopedFileAccess(url: url, bookmarkData: bookmarkData) { scopedURL in
            guard let document = PDFDocument(url: scopedURL) else {
                return SearchOutput(results: [], truncated: false)
            }

            var results: [SearchMatch] = []
            let pageCount = document.pageCount
            let deadline = Date().addingTimeInterval(maxSearchDurationSeconds)
            var truncated = false

            for pageIndex in 0..<pageCount {
                guard !Task.isCancelled else {
                    return SearchOutput(results: results, truncated: true)
                }

                guard Date() < deadline else {
                    return SearchOutput(results: results, truncated: true)
                }

                guard results.count < limit else {
                    return SearchOutput(results: results, truncated: true)
                }

                autoreleasepool {
                    guard var pageText = document.page(at: pageIndex)?.string,
                          !pageText.isEmpty else {
                        return
                    }

                    if pageText.count > maxSearchPageTextCharacters {
                        let end = pageText.index(pageText.startIndex, offsetBy: maxSearchPageTextCharacters)
                        pageText = String(pageText[..<end])
                        truncated = true
                    }

                    var searchRange = pageText.startIndex..<pageText.endIndex
                    while let range = pageText.range(
                        of: query,
                        options: [.caseInsensitive, .diacriticInsensitive],
                        range: searchRange
                    ) {
                        guard !Task.isCancelled else { break }

                        let resultIndex = results.count
                        let matchLocation = SearchTextLocator.match(in: pageText, range: range)
                        results.append(
                            SearchMatch(
                                id: resultIndex,
                                index: resultIndex,
                                pageIndex: pageIndex,
                                matchLocation: matchLocation.location,
                                matchLength: matchLocation.length,
                                pageLabel: "Page \(pageIndex + 1)",
                                excerpt: excerpt(from: pageText, around: range, fallback: query)
                            )
                        )

                        guard results.count < limit else {
                            truncated = true
                            break
                        }
                        searchRange = range.upperBound..<pageText.endIndex
                    }
                }
            }

            return SearchOutput(results: results, truncated: truncated)
        }
    }

    nonisolated private static func excerpt(from text: String?, fallback: String) -> String {
        let source = (text?.isEmpty == false ? text : fallback)
            ?? ""
        let collapsed = source
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard collapsed.count > 90 else {
            return collapsed.isEmpty ? "Match" : collapsed
        }

        return String(collapsed.prefix(90)) + "..."
    }

    nonisolated private static func excerpt(
        from pageText: String,
        around range: Range<String.Index>,
        fallback: String
    ) -> String {
        let prefix = pageText[..<range.lowerBound].suffix(42)
        let match = pageText[range]
        let suffix = pageText[range.upperBound...].prefix(58)
        return excerpt(from: "\(prefix)\(match)\(suffix)", fallback: fallback)
    }

    @objc private func handleOpenFileRequest(_ notification: Notification) {
        if let url = notification.object as? URL {
            openExternalFile(url)
            return
        }

        openPendingExternalFiles()
    }

    private func openPendingExternalFiles() {
        guard let url = ExternalOpenRequestCenter.shared.drainPendingURLs().last else { return }
        openExternalFile(url)
    }

    private func fileExistsForReading(url: URL, bookmarkData: Data?) -> Bool {
        Self.withSecurityScopedFileAccess(url: url, bookmarkData: bookmarkData) { scopedURL in
            FileManager.default.fileExists(atPath: scopedURL.path)
        }
    }

    private func handleMissingPDF(at url: URL) {
        let removed = recents.remove(url: url)
        errorMessage = currentAppLanguage.text(
            removed ? "openPDF.error.missing.removed" : "openPDF.error.missing"
        )
    }
}

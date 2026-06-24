import AppKit
import Combine
import Foundation
import PDFKit
import ReadArcCore
import UniformTypeIdentifiers

@MainActor
final class ReaderModel: NSObject, ObservableObject {
    @Published var document: PDFDocument?
    @Published var documentURL: URL?
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
    @Published var isSidebarVisible = true
    @Published var isInspectorVisible = false
    @Published var rightPanelMode: RightPanelMode = .research
    @Published var inspectorTab: InspectorTab = .search
    @Published var readerMode: ReaderMode = .nativePro
    @Published var selectedChatAgent: ChatAgentProvider = .codexCLI
    @Published var chatMessages: [ChatMessage] = []

    let recents = RecentDocumentsStore()
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var pageTextTask: Task<Void, Never>?
    private var activeLoadID: UUID?
    private var documentBookmarkData: Data?
    private var cachedPageTexts: [DocumentPageText] = []
    nonisolated private static let maxSearchResultCount = 500
    nonisolated private static let minimumSearchLength = 2
    nonisolated private static let maxCachedPageTextPages = 120
    nonisolated private static let maxCachedPageTextCharacters = 220_000
    nonisolated private static let maxStoredChatMessages = 80
    nonisolated private static let cachedPageTextLimit = 4_000

    var hasDocument: Bool {
        document != nil
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
        documentURL?.lastPathComponent ?? "ReadArc"
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

    override init() {
        super.init()
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
        searchTask?.cancel()
        pageTextTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose a PDF document to read."

        if panel.runModal() == .OK, let url = panel.url {
            load(url: url, bookmarkData: Self.makeSecurityScopedBookmark(for: url))
        }
    }

    func load(url: URL, bookmarkData: Data? = nil) {
        guard url.pathExtension.lowercased() == "pdf" else {
            errorMessage = "The selected file is not a PDF."
            return
        }

        guard Self.withSecurityScopedFileAccess(url: url, bookmarkData: bookmarkData, { scopedURL in
            FileManager.default.fileExists(atPath: scopedURL.path)
        }) else {
            errorMessage = "The file no longer exists."
            return
        }

        loadTask?.cancel()
        searchTask?.cancel()
        pageTextTask?.cancel()

        let loadID = UUID()
        activeLoadID = loadID
        errorMessage = nil
        isLoadingDocument = true
        isSearching = false
        isSearchTruncated = false
        isLibraryOverlayVisible = false
        isSidebarVisible = true
        document = nil
        documentURL = url
        pageIndex = 0
        pageCount = 0
        scaleFactor = 1
        searchResults = []
        selectedSearchIndex = nil
        outlineItems = []
        documentBookmarkData = bookmarkData
        cachedPageTexts = []

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
                    self.errorMessage = "The PDF could not be opened."
                    return
                }

                self.document = payload.document
                self.documentURL = url
                self.documentBookmarkData = bookmarkData
                self.pageIndex = 0
                self.pageCount = payload.pageCount
                self.scaleFactor = 1
                self.outlineItems = payload.outlineItems
                self.cachedPageTexts = payload.pageTexts
                self.isLibraryOverlayVisible = false
                self.isSidebarVisible = true
                self.isLoadingDocument = false
                self.recents.add(url: url, bookmarkData: bookmarkData)
                self.schedulePageTextCache(around: 0)
                self.scheduleSearch()
                self.loadTask = nil
            }
        }
    }

    func openRecent(_ recent: RecentDocument) {
        load(url: recent.url, bookmarkData: recent.bookmarkData)
    }

    func openExternalFile(_ url: URL) {
        load(url: url, bookmarkData: Self.makeSecurityScopedBookmark(for: url))
    }

    func removeRecent(_ recent: RecentDocument) {
        recents.remove(recent)
    }

    func clearRecents() {
        recents.clear()
    }

    func closeDocument() {
        loadTask?.cancel()
        searchTask?.cancel()
        pageTextTask?.cancel()
        activeLoadID = nil
        document = nil
        documentURL = nil
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
        cachedPageTexts = []
        pageTextTask = nil
    }

    func revealDocumentInFinder() {
        guard let documentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([documentURL])
    }

    func showLibrary() {
        isLibraryOverlayVisible.toggle()
        isSidebarVisible = true
        readerMode = .nativePro
    }

    func showThumbnails() {
        isLibraryOverlayVisible = false
        isSidebarVisible = true
        readerMode = .nativePro
    }

    func showSidebar() {
        isSidebarVisible = true
        isLibraryOverlayVisible = false
        readerMode = .nativePro
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
        isLibraryOverlayVisible = false
        readerMode = .nativePro
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
        isLibraryOverlayVisible = false
        inspectorTab = .notes
        readerMode = .focus
        rightPanelMode = .focus
        isInspectorVisible = true
    }

    func showResearch(tab: InspectorTab? = nil) {
        isLibraryOverlayVisible = false
        if let tab {
            inspectorTab = tab
        } else if inspectorTab == .notes {
            inspectorTab = .search
        }
        readerMode = .research
        rightPanelMode = .research
        isInspectorVisible = true
    }

    func showChat() {
        isLibraryOverlayVisible = false
        rightPanelMode = .chat
        isInspectorVisible = true
    }

    func toggleChat() {
        if isInspectorVisible && rightPanelMode == .chat {
            isInspectorVisible = false
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
            location: documentLocation,
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
            isInspectorVisible = false
        } else {
            showRightPanel(rightPanelMode)
        }
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
        guard trimmedQuery.count >= Self.minimumSearchLength, let documentURL else {
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
        let bookmarkData = documentBookmarkData
        searchTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            let output = Self.searchPDF(url: documentURL, bookmarkData: bookmarkData, query: trimmedQuery, limit: limit)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self,
                      self.documentURL == documentURL,
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

    nonisolated private static func loadPDFPayload(url: URL, bookmarkData: Data?) -> LoadedPDFPayload? {
        withSecurityScopedFileAccess(url: url, bookmarkData: bookmarkData) { scopedURL in
            autoreleasepool {
                guard let document = PDFDocument(url: scopedURL) else { return nil }
                return LoadedPDFPayload(
                    document: document,
                    pageCount: document.pageCount,
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
        guard let documentURL else { return }
        let candidateIndexes = [pageIndex - 1, pageIndex, pageIndex + 1]
            .filter { $0 >= 0 && $0 < pageCount && cachedText(at: $0) == nil }
        guard !candidateIndexes.isEmpty else { return }

        pageTextTask?.cancel()
        let activeURL = documentURL
        let bookmarkData = documentBookmarkData
        pageTextTask = Task.detached(priority: .utility) { [weak self] in
            let pageTexts = Self.extractPageTexts(url: activeURL, bookmarkData: bookmarkData, pageIndexes: candidateIndexes)
            guard !Task.isCancelled, !pageTexts.isEmpty else { return }

            await MainActor.run {
                guard let self,
                      self.documentURL == activeURL,
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

            for pageIndex in 0..<pageCount {
                guard !Task.isCancelled else {
                    return SearchOutput(results: results, truncated: true)
                }

                guard results.count < limit else {
                    return SearchOutput(results: results, truncated: true)
                }

                autoreleasepool {
                    guard let pageText = document.page(at: pageIndex)?.string,
                          !pageText.isEmpty else {
                        return
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

                        guard results.count < limit else { break }
                        searchRange = range.upperBound..<pageText.endIndex
                    }
                }
            }

            return SearchOutput(results: results, truncated: false)
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
}

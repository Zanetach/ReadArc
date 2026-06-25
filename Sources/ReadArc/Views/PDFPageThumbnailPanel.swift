import PDFKit
import SwiftUI

struct PDFPageThumbnailPanel: View {
    @ObservedObject var model: ReaderModel
    @State private var thumbnailSearchText = ""
    @State private var debouncedThumbnailSearchText = ""
    @State private var selectedFilter: ThumbnailFilter = .all
    @Environment(\.appLanguage) private var language

    var body: some View {
        GeometryReader { proxy in
            let metrics = ThumbnailPanelMetrics(size: proxy.size)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    thumbnailHeader(metrics: metrics)

                    collectionStrip(metrics: metrics)

                    if let document = model.document {
                        ScrollViewReader { proxy in
                            ScrollView {
                                thumbnailContent(document: document, metrics: metrics)
                            }
                            .scrollContentBackground(.hidden)
                            .onAppear {
                                proxy.scrollTo(model.pageIndex, anchor: .center)
                            }
                            .onChange(of: model.pageIndex) { _, pageIndex in
                                proxy.scrollTo(pageIndex, anchor: .center)
                            }
                        }
                    } else {
                        Spacer(minLength: 0)
                    }
                }
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous),
                    fallbackColor: NativeProTheme.sidebar.opacity(0.98),
                    strokeColor: NativeProTheme.separator.opacity(0.78)
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous))
                .shadow(color: NativeProTheme.surfaceShadow.opacity(0.64), radius: metrics.shadowRadius, x: 0, y: metrics.shadowY)
            }
        }
        .padding(.vertical, 0)
        .background(Color.clear)
        .task(id: thumbnailSearchText) {
            await updateDebouncedThumbnailSearchText(thumbnailSearchText)
        }
    }

    private func thumbnailHeader(metrics: ThumbnailPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.headerSpacing) {
            HStack {
                Text(language.text("thumbnails.title"))
                    .font(.system(size: metrics.titleFont, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Spacer(minLength: 0)
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: metrics.searchIconFont, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)

                TextField("Search pages", text: $thumbnailSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: metrics.searchFont, weight: .medium))
            }
            .padding(.horizontal, metrics.searchHorizontalPadding)
            .frame(height: metrics.searchHeight)
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: metrics.searchCornerRadius, style: .continuous),
                fallbackColor: NativeProTheme.panel.opacity(0.82),
                strokeColor: NativeProTheme.separator.opacity(0.62),
                isInteractive: true
            )
        }
        .padding(.horizontal, metrics.headerHorizontalPadding)
        .padding(.top, metrics.headerTopPadding)
        .padding(.bottom, metrics.headerBottomPadding)
    }

    private func collectionStrip(metrics: ThumbnailPanelMetrics) -> some View {
        HStack(spacing: metrics.chipSpacing) {
            ThumbnailChip(title: language.text("library.all"), isActive: selectedFilter == .all, metrics: metrics) {
                selectedFilter = .all
            }
            ThumbnailChip(title: language.text("library.quotes"), isActive: selectedFilter == .quotes, metrics: metrics) {
                selectedFilter = .quotes
            }
            ThumbnailChip(title: language.text("library.specs"), isActive: selectedFilter == .specs, metrics: metrics) {
                selectedFilter = .specs
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, metrics.headerHorizontalPadding)
        .padding(.bottom, metrics.filterBottomPadding)
    }

    @ViewBuilder
    private func thumbnailContent(document: PDFDocument, metrics: ThumbnailPanelMetrics) -> some View {
        let query = debouncedThumbnailSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if document.pageCount <= 0 {
            emptyPagesView(metrics: metrics)
        } else if selectedFilter == .all && query.isEmpty {
            thumbnailList(pageIndexes: 0..<document.pageCount, document: document, metrics: metrics)
        } else {
            let pages = filteredPageIndices(for: document, query: query)
            if pages.isEmpty {
                emptyPagesView(metrics: metrics)
            } else {
                thumbnailList(pageIndexes: pages, document: document, metrics: metrics)
            }
        }
    }

    private func thumbnailList<PageIndexes: RandomAccessCollection>(
        pageIndexes: PageIndexes,
        document: PDFDocument,
        metrics: ThumbnailPanelMetrics
    ) -> some View where PageIndexes.Element == Int {
        LazyVStack(spacing: metrics.thumbnailRowSpacing) {
            ForEach(pageIndexes, id: \.self) { pageIndex in
                PDFPageThumbnailButton(
                    document: document,
                    pageIndex: pageIndex,
                    isSelected: pageIndex == model.pageIndex,
                    metrics: metrics
                ) {
                    model.send(.goToPage(pageIndex))
                }
                .id(pageIndex)
            }
        }
        .padding(.horizontal, metrics.contentPadding)
        .padding(.top, metrics.thumbnailTopPadding)
        .padding(.bottom, metrics.contentPadding)
    }

    private func emptyPagesView(metrics: ThumbnailPanelMetrics) -> some View {
        ContentUnavailableView(
            "No pages",
            systemImage: "doc.text.magnifyingglass",
            description: Text("Try another filter or search.")
        )
        .frame(maxWidth: .infinity, minHeight: metrics.emptyHeight)
    }

    private func filteredPageIndices(for document: PDFDocument, query: String) -> [Int] {
        let basePages: [Int]
        switch selectedFilter {
        case .all:
            if query.isEmpty {
                return Array(0..<document.pageCount)
            }
            basePages = Array(0..<document.pageCount)
        case .quotes:
            basePages = uniqueSortedPages(model.searchMatches.map(\.pageIndex), maxPageCount: document.pageCount)
        case .specs:
            basePages = uniqueSortedPages(model.outlineItems.compactMap(\.pageIndex), maxPageCount: document.pageCount)
        }

        guard !query.isEmpty else { return basePages }
        return basePages.filter { "\($0 + 1)".contains(query) }
    }

    private func uniqueSortedPages(_ pages: [Int], maxPageCount: Int) -> [Int] {
        Array(Set(pages.filter { $0 >= 0 && $0 < maxPageCount })).sorted()
    }

    @MainActor
    private func updateDebouncedThumbnailSearchText(_ text: String) async {
        try? await Task.sleep(nanoseconds: 180_000_000)
        guard !Task.isCancelled else { return }
        debouncedThumbnailSearchText = text
    }
}

private struct ThumbnailPanelMetrics {
    let width: CGFloat
    let height: CGFloat

    init(size: CGSize) {
        self.width = size.width
        self.height = size.height
    }

    private var scale: CGFloat {
        min(max((width - 220) / 150, 0), 1)
    }

    var outerCornerRadius: CGFloat { 20 + scale * 6 }
    var shadowRadius: CGFloat { 16 + scale * 7 }
    var shadowY: CGFloat { 8 + scale * 5 }
    var headerHorizontalPadding: CGFloat { 16 + scale * 10 }
    var headerTopPadding: CGFloat { 16 + scale * 10 }
    var headerBottomPadding: CGFloat { 10 + scale * 3 }
    var headerSpacing: CGFloat { 10 + scale * 4 }
    var titleFont: CGFloat { 18 + scale * 4 }
    var searchHeight: CGFloat { 38 + scale * 7 }
    var searchFont: CGFloat { 12.5 + scale * 1.5 }
    var searchIconFont: CGFloat { 13 + scale * 2 }
    var searchHorizontalPadding: CGFloat { 10 + scale * 3 }
    var searchCornerRadius: CGFloat { 11 + scale * 2 }
    var chipFont: CGFloat { 10 + scale * 1 }
    var chipHeight: CGFloat { 27 + scale * 4 }
    var chipHorizontalPadding: CGFloat { 11 + scale * 4 }
    var chipSpacing: CGFloat { 5 + scale * 2 }
    var filterBottomPadding: CGFloat { 8 + scale * 3 }
    var contentPadding: CGFloat { 12 + scale * 6 }
    var thumbnailTopPadding: CGFloat { 6 + scale * 3 }
    var thumbnailRowSpacing: CGFloat { 10 + scale * 3 }
    var rowHorizontalPadding: CGFloat { 8 + scale * 8 }
    var rowVerticalPadding: CGFloat { 7 + scale * 2 }
    var rowGap: CGFloat { 9 + scale * 5 }
    var pageLabelWidth: CGFloat { 24 + scale * 8 }
    var pageLabelFont: CGFloat { 14 + scale * 2 }
    var thumbnailMinWidth: CGFloat { 116 + scale * 24 }
    var thumbnailMinHeight: CGFloat { 72 + scale * 16 }
    var thumbnailAspect: CGFloat { 0.58 }
    var thumbnailCornerRadius: CGFloat { 10 + scale * 2 }
    var rowCornerRadius: CGFloat { 13 + scale * 2 }
    var rowHeight: CGFloat { 112 + scale * 24 }
    var emptyHeight: CGFloat { 200 + scale * 40 }
}

private enum ThumbnailFilter {
    case all
    case quotes
    case specs
}

private struct ThumbnailChip: View {
    let title: String
    let isActive: Bool
    let metrics: ThumbnailPanelMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: metrics.chipFont, weight: .medium))
                .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.muted)
                .padding(.horizontal, metrics.chipHorizontalPadding)
                .frame(height: metrics.chipHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct PDFPageThumbnailButton: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool
    let metrics: ThumbnailPanelMetrics
    let action: () -> Void
    @State private var image: NSImage?
    @State private var didFailToRender = false

    var body: some View {
        GeometryReader { proxy in
            let thumbnailWidth = max(metrics.thumbnailMinWidth, proxy.size.width - metrics.rowHorizontalPadding * 2 - metrics.pageLabelWidth - metrics.rowGap)
            let thumbnailHeight = max(metrics.thumbnailMinHeight, thumbnailWidth * metrics.thumbnailAspect)

            Button(action: action) {
                HStack(spacing: metrics.rowGap) {
                    Text("\(pageIndex + 1)")
                        .font(.system(size: metrics.pageLabelFont, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isSelected ? NativeProTheme.accent : NativeProTheme.muted)
                        .frame(width: metrics.pageLabelWidth, alignment: .leading)

                    thumbnail
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: metrics.thumbnailCornerRadius, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: metrics.thumbnailCornerRadius, style: .continuous))
                        .shadow(color: NativeProTheme.surfaceShadow.opacity(0.34), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, metrics.rowHorizontalPadding)
                .padding(.vertical, metrics.rowVerticalPadding)
                .frame(width: proxy.size.width, alignment: .leading)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: metrics.rowCornerRadius, style: .continuous),
                    fallbackColor: isSelected ? NativeProTheme.selection.opacity(0.44) : Color.clear,
                    strokeColor: isSelected ? NativeProTheme.accent : .clear,
                    isInteractive: true
                )
                .contentShape(RoundedRectangle(cornerRadius: metrics.rowCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(height: metrics.rowHeight)
        .task(id: thumbnailTaskID) {
            await renderThumbnailIfNeeded()
        }
        .onDisappear {
            if !isSelected {
                image = nil
                didFailToRender = false
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(6)
        } else if didFailToRender {
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 22, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(NativeProTheme.muted.opacity(0.72))

                Text("\(pageIndex + 1)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NativeProTheme.muted.opacity(0.72))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var thumbnailTaskID: String {
        ThumbnailMemoryCache.key(for: document, pageIndex: pageIndex) as String
    }

    @MainActor
    private func renderThumbnailIfNeeded() async {
        guard image == nil else {
            return
        }

        didFailToRender = false
        let cacheKey = ThumbnailMemoryCache.key(for: document, pageIndex: pageIndex)
        if let cachedImage = ThumbnailMemoryCache.shared.image(for: cacheKey) {
            image = cachedImage
            return
        }

        guard let thumbnail = await ThumbnailRenderService.render(
            documentURL: document.documentURL,
            pageIndex: pageIndex,
            targetSize: NSSize(width: 260, height: 152)
        ) else {
            didFailToRender = true
            return
        }

        guard !Task.isCancelled else { return }
        ThumbnailMemoryCache.shared.set(thumbnail, for: cacheKey)
        image = thumbnail
    }
}

private enum ThumbnailRenderService {
    static func render(documentURL: URL?, pageIndex: Int, targetSize: NSSize) async -> NSImage? {
        guard let documentURL else {
            return nil
        }

        let width = targetSize.width
        let height = targetSize.height
        let result = await Task.detached(priority: .utility) { () -> RenderedThumbnail in
            autoreleasepool {
                let didStartAccessing = documentURL.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccessing {
                        documentURL.stopAccessingSecurityScopedResource()
                    }
                }

                guard let document = PDFDocument(url: documentURL),
                      pageIndex >= 0,
                      pageIndex < document.pageCount,
                      let page = document.page(at: pageIndex) else {
                    return RenderedThumbnail(image: nil)
                }

                let image = page.thumbnail(
                    of: NSSize(width: width, height: height),
                    for: .cropBox
                )
                guard image.size.width > 0, image.size.height > 0 else {
                    return RenderedThumbnail(image: nil)
                }
                return RenderedThumbnail(image: image)
            }
        }.value

        return result.image
    }
}

private struct RenderedThumbnail: @unchecked Sendable {
    let image: NSImage?
}

@MainActor
private final class ThumbnailMemoryCache {
    static let shared = ThumbnailMemoryCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 96
        cache.totalCostLimit = 32 * 1024 * 1024
    }

    static func key(for document: PDFDocument, pageIndex: Int) -> NSString {
        let documentID = document.documentURL?.path ?? "\(ObjectIdentifier(document))"
        return "\(documentID)#\(pageIndex)" as NSString
    }

    func image(for key: NSString) -> NSImage? {
        cache.object(forKey: key)
    }

    func set(_ image: NSImage, for key: NSString) {
        cache.setObject(image, forKey: key, cost: image.memoryCost)
    }
}

private extension NSImage {
    var memoryCost: Int {
        max(1, Int(size.width * size.height * 4))
    }
}

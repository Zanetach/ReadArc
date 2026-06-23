import PDFKit
import SwiftUI

struct PDFPageThumbnailPanel: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        VStack(spacing: 0) {
            if let document = model.document {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(0..<document.pageCount, id: \.self) { pageIndex in
                                PDFPageThumbnailButton(
                                    document: document,
                                    pageIndex: pageIndex,
                                    isSelected: pageIndex == model.pageIndex
                                ) {
                                    model.send(.goToPage(pageIndex))
                                }
                                .id(pageIndex)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 22)
                    }
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        proxy.scrollTo(model.pageIndex, anchor: .center)
                    }
                    .onChange(of: model.pageIndex) { _, pageIndex in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            proxy.scrollTo(pageIndex, anchor: .center)
                        }
                    }
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .background(NativeProTheme.window.opacity(0.96))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(width: 1)
        }
    }
}

private struct PDFPageThumbnailButton: View {
    let document: PDFDocument
    let pageIndex: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var image: NSImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                thumbnail
                    .frame(width: 124, height: 164)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(isSelected ? NativeProTheme.accent : NativeProTheme.separator, lineWidth: isSelected ? 2.5 : 1)
                    }
                    .shadow(color: .black.opacity(0.34), radius: 8, x: 0, y: 4)

                Text("\(pageIndex + 1)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NativeProTheme.ink)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(isSelected ? NativeProTheme.selection : Color.clear, in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: document.pageCount + pageIndex) {
            renderThumbnailIfNeeded()
        }
        .onDisappear {
            if !isSelected {
                image = nil
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
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func renderThumbnailIfNeeded() {
        guard image == nil else {
            return
        }

        let cacheKey = ThumbnailMemoryCache.key(for: document, pageIndex: pageIndex)
        if let cachedImage = ThumbnailMemoryCache.shared.image(for: cacheKey) {
            image = cachedImage
            return
        }

        guard let page = document.page(at: pageIndex) else {
            return
        }

        let thumbnail = page.thumbnail(
            of: NSSize(width: 124, height: 164),
            for: .cropBox
        )
        ThumbnailMemoryCache.shared.set(thumbnail, for: cacheKey)
        image = thumbnail
    }
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

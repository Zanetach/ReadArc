import ReadArcCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var recents: RecentDocumentsStore
    @State private var librarySearchText = ""
    @Environment(\.appLanguage) private var language

    let selectedURL: URL?
    let readerMode: ReaderMode
    let openDocument: () -> Void
    let openRecent: (RecentDocument) -> Void
    let removeRecent: (RecentDocument) -> Void
    let clearRecents: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader

            collectionStrip

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let selectedDocument {
                        SectionLabel("Pinned")
                        RecentDocumentRow(
                            document: selectedDocument,
                            isSelected: true,
                            openRecent: openRecent,
                            removeRecent: removeRecent
                        )
                    }

                    SectionLabel("Recent")

                    if filteredDocuments.isEmpty {
                        emptyRecentState
                    } else {
                        ForEach(filteredDocuments) { document in
                            RecentDocumentRow(
                                document: document,
                                isSelected: document.url == selectedURL,
                                openRecent: openRecent,
                                removeRecent: removeRecent
                            )
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)

            libraryFooter
        }
        .opacity(readerMode == .focus ? 0.35 : 1)
        .background(NativeProTheme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(width: 1)
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text("library.title"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text(language.text("library.subtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(NativeProTheme.muted)
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)

                TextField(language.text("library.search"), text: $librarySearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(NativeProTheme.panel.opacity(0.68), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(NativeProTheme.separator, lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(height: 1)
        }
    }

    private var collectionStrip: some View {
        HStack(spacing: 7) {
            CollectionChip(title: language.text("library.all"), isActive: true)
            CollectionChip(title: language.text("library.quotes"), isActive: false)
            CollectionChip(title: language.text("library.specs"), isActive: false)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var libraryFooter: some View {
        VStack(spacing: 10) {
            Button(action: openDocument) {
                Label(language.text("openPDF"), systemImage: "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(NativeProTheme.accent)
            }
            .buttonStyle(.plain)

            if !recents.documents.isEmpty {
                Button(action: clearRecents) {
                    Label(language.text("clearRecent"), systemImage: "trash")
                        .font(.system(size: 11, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .foregroundStyle(NativeProTheme.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(height: 1)
        }
    }

    private var selectedDocument: RecentDocument? {
        guard let selectedURL else { return nil }
        return recents.documents.first { $0.url == selectedURL }
    }

    private var filteredDocuments: [RecentDocument] {
        let query = librarySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let documents = recents.documents.filter { $0.url != selectedURL }
        guard !query.isEmpty else { return documents }
        return documents.filter { document in
            document.title.localizedCaseInsensitiveContains(query)
                || document.url.path.localizedCaseInsensitiveContains(query)
        }
    }

    private var emptyRecentState: some View {
        Text(recents.documents.isEmpty ? language.text("library.noRecent") : language.text("library.noMatches"))
            .font(.system(size: 12))
            .foregroundStyle(NativeProTheme.muted)
            .padding(.horizontal, 7)
            .padding(.vertical, 10)
    }
}

private struct RecentDocumentRow: View {
    let document: RecentDocument
    let isSelected: Bool
    let openRecent: (RecentDocument) -> Void
    let removeRecent: (RecentDocument) -> Void

    var body: some View {
        Button {
            openRecent(document)
        } label: {
            HStack(spacing: 8) {
                PDFMiniIcon()

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(isSelected ? NativeProTheme.accent : NativeProTheme.ink)

                    HStack(spacing: 7) {
                        Text(document.url.deletingLastPathComponent().lastPathComponent.isEmpty ? "Local" : document.url.deletingLastPathComponent().lastPathComponent)
                        Text("PDF")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(NativeProTheme.muted)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .background(isSelected ? NativeProTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? NativeProTheme.accent.opacity(0.18) : .clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from Recent") {
                removeRecent(document)
            }
        }
    }
}

private struct SectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(NativeProTheme.faint)
            .padding(.horizontal, 7)
            .padding(.top, 12)
            .padding(.bottom, 7)
    }
}

private struct CollectionChip: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.muted)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(isActive ? NativeProTheme.selection.opacity(0.86) : NativeProTheme.panel.opacity(0.45), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isActive ? NativeProTheme.accent.opacity(0.24) : NativeProTheme.separator, lineWidth: 1)
            }
    }
}

private struct PDFMiniIcon: View {
    var body: some View {
        Text("PDF")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(NativeProTheme.accent)
            .frame(width: 22, height: 28)
            .background(NativeProTheme.tile.opacity(0.86), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(NativeProTheme.separator, lineWidth: 1)
            }
    }
}

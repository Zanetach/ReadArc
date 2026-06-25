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
            VStack(spacing: 0) {
                libraryHeader

                collectionStrip

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let selectedDocument {
                            SectionLabel(language.text("library.pinned"))
                            RecentDocumentRow(
                                document: selectedDocument,
                                isSelected: true,
                                openRecent: openRecent,
                                removeRecent: removeRecent
                            )
                        }

                        SectionLabel(language.text("library.recent"))

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
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                fallbackColor: NativeProTheme.sidebar,
                strokeColor: NativeProTheme.separator.opacity(0.55)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .padding(.trailing, 12)
        .opacity(readerMode == .focus ? 0.35 : 1)
        .background(Color.clear)
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
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 7, style: .continuous),
                fallbackColor: NativeProTheme.panel.opacity(0.86),
                strokeColor: NativeProTheme.separator.opacity(0.72)
            )
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
    @Environment(\.appLanguage) private var language

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
                        Text(document.url.deletingLastPathComponent().lastPathComponent.isEmpty ? language.text("library.local") : document.url.deletingLastPathComponent().lastPathComponent)
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
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 9, style: .continuous),
                fallbackColor: isSelected ? NativeProTheme.selection : Color.clear,
                strokeColor: isSelected ? NativeProTheme.accent.opacity(0.18) : .clear,
                isInteractive: true,
                tint: isSelected ? NativeProTheme.accent.opacity(0.12) : nil
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(language.text("library.removeRecent")) {
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
            .readArcGlass(
                in: Capsule(),
                fallbackColor: isActive ? NativeProTheme.selection.opacity(0.72) : NativeProTheme.panel.opacity(0.52),
                strokeColor: isActive ? NativeProTheme.accent.opacity(0.18) : NativeProTheme.separator.opacity(0.70),
                isInteractive: true,
                tint: isActive ? NativeProTheme.accent.opacity(0.08) : nil
            )
    }
}

private struct PDFMiniIcon: View {
    var body: some View {
        Text("PDF")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(NativeProTheme.muted)
            .frame(width: 22, height: 28)
            .background(NativeProTheme.tile.opacity(0.86), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(NativeProTheme.separator, lineWidth: 1)
            }
    }
}

import SwiftUI

struct DocumentInspectorView: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

            currentSectionHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if model.hasDocument {
                        DocumentMetricsPanel(model: model)
                        SynthesisPanel(model: model)

                        switch model.inspectorTab {
                        case .search:
                            SearchMatchesPanel(model: model)
                        case .outline:
                            OutlinePanel(model: model)
                        case .notes:
                            NotesPanel(model: model)
                        }

                        FileLocationPanel(model: model)
                    } else {
                        emptyState
                    }
                }
                .padding(14)
            }
        }
        .background(inspectorBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(width: 1)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                headerText

                Spacer(minLength: 8)

                readerModePicker
            }

            VStack(alignment: .leading, spacing: 10) {
                headerText
                readerModePicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(language.text("inspector.title"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NativeProTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(language.text("inspector.subtitle"))
                .font(.system(size: 11))
                .foregroundStyle(NativeProTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(minWidth: 88, maxWidth: .infinity, alignment: .leading)
    }

    private var readerModePicker: some View {
        Picker("Reader Mode", selection: $model.readerMode) {
            ForEach(ReaderMode.allCases) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.mini)
        .frame(width: 148)
    }

    private var currentSectionHeader: some View {
        HStack(spacing: 9) {
            Image(systemName: model.inspectorTab.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(NativeProTheme.accent)
                .frame(width: 26, height: 26)
                .background(NativeProTheme.selection.opacity(0.82), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.inspectorTab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text(model.inspectorTab.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(NativeProTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(height: 1)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            language.text("empty.title"),
            systemImage: "doc.richtext",
            description: Text(language.text("chat.noPDFContext"))
        )
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var inspectorBackground: Color {
        switch model.readerMode {
        case .nativePro, .focus:
            return NativeProTheme.inspector
        case .research:
            return NativeProTheme.inspectorResearch
        }
    }
}

private struct DocumentMetricsPanel: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
            MetricTile(value: "\(model.pageCount)", label: "pages")
            MetricTile(value: model.searchLabel, label: "matches")
            MetricTile(value: "\(model.outlineItems.count)", label: "outline")
            MetricTile(value: model.fileSizeLabel, label: "size")
        }
    }
}

private struct SynthesisPanel: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        InspectorPanel(title: "Summary", trailing: model.hasDocument ? "page \(model.pageIndex + 1)" : nil) {
            VStack(alignment: .leading, spacing: 7) {
                Text(model.hasDocument ? currentHeadline : "Open a PDF to inspect its structure.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NativeProTheme.ink)

                Text(model.hasDocument ? currentSummary : "Search results, outline, file metadata, and notes will appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(NativeProTheme.ink.opacity(0.76))
                    .lineLimit(2)

                if model.hasDocument {
                    HStack(spacing: 6) {
                        TagLabel("page \(model.pageIndex + 1)")
                        TagLabel(model.readerMode.title.lowercased())
                    }
                }
            }
        }
    }

    private var currentHeadline: String {
        if model.isSearching {
            return "Searching current PDF."
        }
        return model.searchResults.isEmpty ? "Ready for focused reading." : "Search trail ready."
    }

    private var currentSummary: String {
        if model.isSearching {
            return "Indexing text in the background so reading stays responsive."
        }
        if model.searchResults.isEmpty {
            return "Use search to create page-linked evidence while keeping the PDF in view."
        }
        return model.isSearchTruncated
            ? "Showing the first \(model.searchResults.count) matches to keep memory usage stable."
            : "\(model.searchResults.count) matches are indexed for quick page navigation."
    }
}

private struct SearchMatchesPanel: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        InspectorPanel(title: "Search Matches") {
            if model.isSearching {
                Text("Searching in the background...")
                    .font(.caption)
                    .foregroundStyle(NativeProTheme.muted)
            } else if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Use search to list matches here.")
                    .font(.caption)
                    .foregroundStyle(NativeProTheme.muted)
            } else if model.searchMatches.isEmpty {
                Text("No matches for \"\(model.searchText)\".")
                    .font(.caption)
                    .foregroundStyle(NativeProTheme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.searchMatches.prefix(8)) { match in
                        Button {
                            model.selectSearchResult(at: match.index)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(match.pageLabel)
                                    .font(.caption.weight(.semibold))
                                Text(match.excerpt)
                                    .font(.caption)
                                    .foregroundStyle(NativeProTheme.muted)
                                    .lineLimit(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                            .background(matchBackground(for: match), in: RoundedRectangle(cornerRadius: 7))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(match.index == model.selectedSearchIndex ? NativeProTheme.searchBorder.opacity(0.35) : .clear)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func matchBackground(for match: SearchMatch) -> Color {
        match.index == model.selectedSearchIndex
            ? NativeProTheme.searchHit
            : NativeProTheme.panel
    }
}

private struct OutlinePanel: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        InspectorPanel(title: "Outline") {
            if model.outlineItems.isEmpty {
                Text("This PDF does not expose an outline.")
                    .font(.caption)
                    .foregroundStyle(NativeProTheme.muted)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.outlineItems) { item in
                        Button {
                            model.goToOutlineItem(item)
                        } label: {
                            HStack(spacing: 8) {
                                Text(item.title)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.pageLabel)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(NativeProTheme.muted)
                            }
                            .font(.caption)
                            .padding(.leading, CGFloat(item.depth) * 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
            }
        }
    }
}

private struct FileLocationPanel: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        InspectorPanel(title: "File") {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.documentTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)

                Text(model.documentLocation)
                    .font(.caption)
                    .foregroundStyle(NativeProTheme.muted)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct NotesPanel: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        InspectorPanel(title: "Notes") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Page \(max(model.pageIndex + 1, 1))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text("Notes will support page-linked annotations in the next pass.")
                    .font(.system(size: 12))
                    .foregroundStyle(NativeProTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct InspectorPanel<Content: View>: View {
    let title: String
    var trailing: String?
    @ViewBuilder var content: Content

    init(title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NativeProTheme.muted)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NativeProTheme.muted)
                }
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeProTheme.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(NativeProTheme.separator)
        }
    }
}

private struct MetricTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(NativeProTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(NativeProTheme.tile.opacity(0.74), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct TagLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(NativeProTheme.accent)
            .padding(.horizontal, 7)
            .frame(height: 19)
            .background(NativeProTheme.selection.opacity(0.86), in: Capsule())
    }
}

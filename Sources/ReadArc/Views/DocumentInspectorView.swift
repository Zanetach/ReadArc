import SwiftUI

struct DocumentInspectorView: View {
    @ObservedObject var model: ReaderModel
    let modeSwitcher: AnyView
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header

                currentSectionHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if model.hasDocument {
                            DocumentMetricsPanel(model: model)
                            SynthesisPanel(model: model)

                            switch model.rightPanelMode {
                            case .focus:
                                NotesPanel(model: model)
                            case .research:
                                researchPanels
                            case .chat:
                                EmptyView()
                            }

                            FileLocationPanel(model: model)
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .scrollContentBackground(.hidden)
            }
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                fallbackColor: NativeProTheme.sidebar,
                strokeColor: NativeProTheme.separator.opacity(0.55)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .background(Color.clear)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Spacer(minLength: 0)
                modeSwitcher
                Spacer(minLength: 0)
            }

            headerText
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.rightPanelMode.title(language: language))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NativeProTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(model.rightPanelMode.subtitle(language: language))
                .font(.system(size: 11))
                .foregroundStyle(NativeProTheme.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(minWidth: 88, maxWidth: .infinity, alignment: .leading)
    }

    private var currentSectionHeader: some View {
        HStack(spacing: 9) {
            Image(systemName: sectionIcon)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(NativeProTheme.accent)
                .frame(width: 26, height: 26)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous),
                    fallbackColor: NativeProTheme.selection.opacity(0.68),
                    strokeColor: NativeProTheme.accent.opacity(0.15),
                    tint: NativeProTheme.accent.opacity(0.08)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(sectionTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text(sectionSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(NativeProTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 12, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.76),
            strokeColor: NativeProTheme.separator.opacity(0.58)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var researchPanels: some View {
        if model.inspectorTab == .outline {
            OutlinePanel(model: model)
            SearchMatchesPanel(model: model)
        } else {
            SearchMatchesPanel(model: model)
            OutlinePanel(model: model)
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

    private var sectionIcon: String {
        switch model.rightPanelMode {
        case .focus:
            return RightPanelMode.focus.systemImage
        case .research:
            return model.inspectorTab.systemImage
        case .chat:
            return RightPanelMode.chat.systemImage
        }
    }

    private var sectionTitle: String {
        switch model.rightPanelMode {
        case .focus:
            return language.text("panel.focus.current")
        case .research:
            return model.inspectorTab.title(language: language)
        case .chat:
            return RightPanelMode.chat.title(language: language)
        }
    }

    private var sectionSummary: String {
        switch model.rightPanelMode {
        case .focus:
            return language.text("panel.focus.summary")
        case .research:
            return model.inspectorTab.summary(language: language)
        case .chat:
            return RightPanelMode.chat.subtitle(language: language)
        }
    }
}

private struct DocumentMetricsPanel: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
            MetricTile(value: "\(model.pageCount)", label: language.text("inspector.metric.pages"))
            MetricTile(value: model.searchLabel, label: language.text("inspector.metric.matches"))
            MetricTile(value: "\(model.outlineItems.count)", label: language.text("inspector.metric.outline"))
            MetricTile(value: model.fileSizeLabel, label: language.text("inspector.metric.size"))
        }
    }
}

private struct SynthesisPanel: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language

    var body: some View {
        InspectorPanel(title: language.text("inspector.summary"), trailing: model.hasDocument ? String(format: language.text("inspector.page"), model.pageIndex + 1) : nil) {
            VStack(alignment: .leading, spacing: 7) {
                Text(model.hasDocument ? currentHeadline : language.text("inspector.summary.empty.title"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NativeProTheme.ink)

                Text(model.hasDocument ? currentSummary : language.text("inspector.summary.empty.body"))
                    .font(.system(size: 12))
                    .foregroundStyle(NativeProTheme.ink.opacity(0.76))
                    .lineLimit(2)

                if model.hasDocument {
                    HStack(spacing: 6) {
                        TagLabel(String(format: language.text("inspector.page"), model.pageIndex + 1))
                        TagLabel(model.rightPanelMode.title(language: language).lowercased())
                    }
                }
            }
        }
    }

    private var currentHeadline: String {
        if model.isSearching {
            return language.text("inspector.summary.searching.title")
        }
        return model.searchResults.isEmpty
            ? language.text("inspector.summary.ready.title")
            : language.text("inspector.summary.results.title")
    }

    private var currentSummary: String {
        if model.isSearching {
            return language.text("inspector.summary.searching.body")
        }
        if model.searchResults.isEmpty {
            return language.text("inspector.summary.ready.body")
        }
        return model.isSearchTruncated
            ? String(format: language.text("inspector.summary.results.truncated"), model.searchResults.count)
            : String(format: language.text("inspector.summary.results.body"), model.searchResults.count)
    }
}

private struct SearchMatchesPanel: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language

    var body: some View {
        InspectorPanel(title: language.text("inspector.searchMatches")) {
            if model.isSearching {
                Text(language.text("inspector.search.searching"))
                    .font(.caption)
                    .foregroundStyle(NativeProTheme.muted)
            } else if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(language.text("inspector.search.empty"))
                    .font(.caption)
                    .foregroundStyle(NativeProTheme.muted)
            } else if model.searchMatches.isEmpty {
                Text(String(format: language.text("inspector.search.noResults"), model.searchText))
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
                            .readArcGlass(
                                in: RoundedRectangle(cornerRadius: 7),
                                fallbackColor: matchBackground(for: match),
                                strokeColor: match.index == model.selectedSearchIndex ? NativeProTheme.searchBorder.opacity(0.35) : .clear,
                                isInteractive: true,
                                tint: match.index == model.selectedSearchIndex ? NativeProTheme.searchBorder.opacity(0.10) : nil
                            )
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
    @Environment(\.appLanguage) private var language

    var body: some View {
        InspectorPanel(title: language.text("inspector.outline")) {
            if model.outlineItems.isEmpty {
                Text(language.text("inspector.outline.empty"))
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
    @Environment(\.appLanguage) private var language

    var body: some View {
        InspectorPanel(title: language.text("inspector.file")) {
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
    @Environment(\.appLanguage) private var language

    var body: some View {
        InspectorPanel(title: language.text("inspector.notes")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: language.text("inspector.page"), max(model.pageIndex + 1, 1)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text(language.text("inspector.note.placeholder"))
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
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 14, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.76),
            strokeColor: NativeProTheme.separator.opacity(0.70)
        )
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
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 12, style: .continuous),
            fallbackColor: NativeProTheme.tile.opacity(0.70),
            strokeColor: NativeProTheme.separator.opacity(0.55)
        )
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
            .readArcGlass(
                in: Capsule(),
                fallbackColor: NativeProTheme.selection.opacity(0.70),
                strokeColor: NativeProTheme.accent.opacity(0.16),
                tint: NativeProTheme.accent.opacity(0.08)
            )
    }
}

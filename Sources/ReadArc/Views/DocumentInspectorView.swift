import AppKit
import SwiftUI

struct DocumentInspectorView: View {
    @ObservedObject var model: ReaderModel
    let modeSwitcher: AnyView
    @Environment(\.appLanguage) private var language

    var body: some View {
        GeometryReader { proxy in
            let metrics = InspectorLayoutMetrics(size: proxy.size)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    header(metrics: metrics)

                    ScrollView {
                        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
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

                                if model.rightPanelMode != .research {
                                    FileLocationPanel(model: model)
                                }
                            } else {
                                emptyState
                            }
                        }
                        .padding(.horizontal, metrics.contentPadding)
                        .padding(.bottom, metrics.contentPadding)
                    }
                    .scrollContentBackground(.hidden)
                }
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous),
                    fallbackColor: NativeProTheme.sidebar.opacity(0.98),
                    strokeColor: NativeProTheme.separator.opacity(0.78)
                )
                .clipShape(RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous))
                .shadow(color: NativeProTheme.surfaceShadow.opacity(0.66), radius: metrics.outerShadowRadius, x: 0, y: metrics.outerShadowY)
            }
            .environment(\.inspectorLayoutMetrics, metrics)
        }
        .background(Color.clear)
    }

    private func header(metrics: InspectorLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            modeSwitcher
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, metrics.headerHorizontalPadding)
        .padding(.top, metrics.headerTopPadding)
        .padding(.bottom, metrics.headerBottomPadding)
    }

    @ViewBuilder
    private var researchPanels: some View {
        SearchMatchesPanel(model: model)
        OutlinePanel(model: model)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            language.text("empty.title"),
            systemImage: "doc.richtext",
            description: Text(language.text("chat.noPDFContext"))
        )
        .frame(maxWidth: .infinity, minHeight: 260)
    }
}

private struct InspectorLayoutMetrics: Equatable {
    let width: CGFloat
    let height: CGFloat

    init(size: CGSize) {
        self.width = size.width
        self.height = size.height
    }

    private var scale: CGFloat {
        min(max((width - 260) / 160, 0), 1)
    }

    var outerCornerRadius: CGFloat { 20 + scale * 6 }
    var outerShadowRadius: CGFloat { 16 + scale * 8 }
    var outerShadowY: CGFloat { 8 + scale * 6 }
    var contentPadding: CGFloat { 12 + scale * 8 }
    var headerHorizontalPadding: CGFloat { contentPadding + 2 }
    var headerTopPadding: CGFloat { 14 + scale * 10 }
    var headerBottomPadding: CGFloat { 8 + scale * 6 }
    var sectionSpacing: CGFloat { 10 + scale * 4 }
    var cardPadding: CGFloat { 12 + scale * 4 }
    var cardSpacing: CGFloat { 8 + scale * 2 }
    var cardCornerRadius: CGFloat { 14 + scale * 4 }
    var iconFont: CGFloat { 14 + scale * 2 }
    var titleFont: CGFloat { 14 + scale * 2 }
    var trailingFont: CGFloat { 11 + scale * 2 }
    var bodyFont: CGFloat { 12 + scale * 1.5 }
    var captionFont: CGFloat { 10.5 + scale * 1.5 }
    var metricGridSpacing: CGFloat { 8 + scale * 4 }
    var metricColumnCount: Int { width < 370 ? 2 : 4 }
    var metricTileHeight: CGFloat { metricColumnCount == 2 ? 82 + scale * 10 : 88 + scale * 16 }
    var metricIconFont: CGFloat { 19 + scale * 5 }
    var metricValueFont: CGFloat { 15 + scale * 2 }
    var metricLabelFont: CGFloat { 10.5 + scale * 1 }
    var tagHeight: CGFloat { 18 + scale * 1 }
    var tagFont: CGFloat { 9.5 + scale * 0.5 }
    var badgeHeight: CGFloat { 22 + scale * 2 }
}

private struct InspectorLayoutMetricsKey: EnvironmentKey {
    static let defaultValue = InspectorLayoutMetrics(size: CGSize(width: 360, height: 700))
}

private extension EnvironmentValues {
    var inspectorLayoutMetrics: InspectorLayoutMetrics {
        get { self[InspectorLayoutMetricsKey.self] }
        set { self[InspectorLayoutMetricsKey.self] = newValue }
    }
}

private struct DocumentMetricsPanel: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language
    @Environment(\.inspectorLayoutMetrics) private var metrics

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: metrics.metricGridSpacing), count: metrics.metricColumnCount),
            spacing: metrics.metricGridSpacing
        ) {
            MetricTile(systemImage: "doc.text", value: "\(model.pageCount)", label: language.text("inspector.metric.pages"))
            MetricTile(systemImage: "magnifyingglass", value: model.searchLabel, label: language.text("inspector.metric.matches"))
            MetricTile(systemImage: "list.bullet", value: "\(model.outlineItems.count)", label: language.text("inspector.metric.outline"))
            MetricTile(systemImage: "doc", value: model.fileSizeLabel, label: language.text("inspector.metric.size"))
        }
    }
}

private struct SynthesisPanel: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language
    @Environment(\.inspectorLayoutMetrics) private var metrics

    var body: some View {
        InspectorPanel(
            title: language.text("inspector.summary"),
            systemImage: "sparkles",
            trailing: "Copy",
            trailingAction: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(currentSummary, forType: .string)
            }
        ) {
            Text(model.hasDocument ? currentSummary : language.text("inspector.summary.empty.body"))
                .font(.system(size: metrics.bodyFont, weight: .semibold))
                .foregroundStyle(NativeProTheme.ink.opacity(0.84))
                .lineLimit(metrics.width < 330 ? 4 : 3)
                .fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.inspectorLayoutMetrics) private var metrics

    var body: some View {
        InspectorPanel(
            title: "\(language.text("inspector.searchMatches")) (\(model.searchResults.count))",
            systemImage: "list.bullet",
            trailing: "View all",
            trailingAction: {
            model.showResearch(tab: .search)
            }
        ) {
            if model.isSearching {
                Text(language.text("inspector.search.searching"))
                    .font(.system(size: metrics.captionFont, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)
            } else if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(language.text("inspector.search.empty"))
                    .font(.system(size: metrics.captionFont, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)
            } else if model.searchMatches.isEmpty {
                Text(String(format: language.text("inspector.search.noResults"), model.searchText))
                    .font(.system(size: metrics.captionFont, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.searchMatches.prefix(3)) { match in
                        Button {
                            model.selectSearchResult(at: match.index)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text(match.pageLabel)
                                    .font(.system(size: metrics.captionFont, weight: .semibold))
                                    .foregroundStyle(NativeProTheme.ink)
                                    .padding(.horizontal, 8)
                                    .frame(height: metrics.badgeHeight)
                                    .readArcGlass(
                                        in: Capsule(),
                                        fallbackColor: NativeProTheme.selection.opacity(0.74),
                                        strokeColor: NativeProTheme.separator.opacity(0.30)
                                    )

                                highlightedExcerpt(match.excerpt)
                                    .font(.system(size: metrics.bodyFont, weight: .semibold))
                                    .foregroundStyle(NativeProTheme.ink.opacity(0.84))
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func highlightedExcerpt(_ excerpt: String) -> Text {
        Text(excerpt)
    }
}

private struct OutlinePanel: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language
    @Environment(\.inspectorLayoutMetrics) private var metrics

    var body: some View {
        InspectorPanel(
            title: "\(language.text("inspector.outline")) (\(model.outlineItems.count))",
            systemImage: "circle",
            trailing: "View all",
            trailingAction: {
            model.showResearch(tab: .outline)
            }
        ) {
            if model.outlineItems.isEmpty {
                Text(language.text("inspector.outline.empty"))
                    .font(.system(size: metrics.captionFont, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.outlineItems.prefix(6)) { item in
                        Button {
                            model.goToOutlineItem(item)
                        } label: {
                            HStack(spacing: 8) {
                                Text(item.title)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.pageLabel)
                                    .font(.system(size: metrics.captionFont, weight: .medium, design: .monospaced))
                                    .foregroundStyle(NativeProTheme.muted)
                            }
                            .font(.system(size: metrics.bodyFont, weight: (item.pageIndex ?? -1) == model.pageIndex ? .semibold : .medium))
                            .foregroundStyle((item.pageIndex ?? -1) == model.pageIndex ? NativeProTheme.accent : NativeProTheme.ink.opacity(0.86))
                            .padding(.leading, CGFloat(item.depth) * 14)
                            .padding(.vertical, 5)
                            .padding(.horizontal, (item.pageIndex ?? -1) == model.pageIndex ? 8 : 0)
                            .background {
                                if (item.pageIndex ?? -1) == model.pageIndex {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(NativeProTheme.selection.opacity(0.88))
                                }
                            }
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
    @Environment(\.inspectorLayoutMetrics) private var metrics

    var body: some View {
        InspectorPanel(title: language.text("inspector.file")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.documentTitle)
                    .font(.system(size: metrics.captionFont, weight: .semibold))
                    .lineLimit(2)

                Text(model.documentLocation)
                    .font(.system(size: metrics.captionFont, weight: .medium))
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
    @Environment(\.inspectorLayoutMetrics) private var metrics

    var body: some View {
        InspectorPanel(title: language.text("inspector.notes")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: language.text("inspector.page"), max(model.pageIndex + 1, 1)))
                    .font(.system(size: metrics.captionFont, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text(language.text("inspector.note.placeholder"))
                    .font(.system(size: metrics.captionFont, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct InspectorPanel<Content: View>: View {
    let title: String
    var systemImage: String?
    var trailing: String?
    var trailingAction: (() -> Void)?
    @ViewBuilder var content: Content
    @Environment(\.inspectorLayoutMetrics) private var metrics

    init(
        title: String,
        systemImage: String? = nil,
        trailing: String? = nil,
        trailingAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
        self.trailingAction = trailingAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.cardSpacing) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: metrics.iconFont, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(systemImage == "sparkles" ? NativeProTheme.success : NativeProTheme.accent)
                }

                Text(title)
                    .font(.system(size: metrics.titleFont, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)

                if let trailing {
                    if let trailingAction {
                        Button(action: trailingAction) {
                            Text(trailing)
                                .font(.system(size: metrics.trailingFont, weight: .semibold))
                                .foregroundStyle(trailing == "Copy" ? NativeProTheme.ink.opacity(0.72) : NativeProTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .help(trailing)
                    } else {
                        Text(trailing)
                            .font(.system(size: metrics.trailingFont, weight: .semibold))
                            .foregroundStyle(trailing == "Copy" ? NativeProTheme.ink.opacity(0.72) : NativeProTheme.accent)
                    }
                }
            }

            content
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.82),
            strokeColor: NativeProTheme.separator.opacity(0.64)
        )
    }
}

private struct MetricTile: View {
    let systemImage: String
    let value: String
    let label: String
    @Environment(\.inspectorLayoutMetrics) private var metrics

    var body: some View {
        VStack(spacing: metrics.width < 330 ? 5 : 7) {
            Image(systemName: systemImage)
                .font(.system(size: metrics.metricIconFont, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(NativeProTheme.accent)

            Text(value)
                .font(.system(size: metrics.metricValueFont, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(label)
                .font(.system(size: metrics.metricLabelFont, weight: .semibold))
                .foregroundStyle(NativeProTheme.ink.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity)
        .frame(height: metrics.metricTileHeight)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: metrics.cardCornerRadius - 2, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.76),
            strokeColor: NativeProTheme.separator.opacity(0.56)
        )
    }
}

private struct TagLabel: View {
    let title: String
    @Environment(\.inspectorLayoutMetrics) private var metrics

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: metrics.tagFont, weight: .semibold))
            .foregroundStyle(NativeProTheme.accent)
            .padding(.horizontal, metrics.width < 330 ? 6 : 7)
            .frame(height: metrics.tagHeight)
            .readArcGlass(
                in: Capsule(),
                fallbackColor: NativeProTheme.selection.opacity(0.70),
                strokeColor: NativeProTheme.accent.opacity(0.16),
                tint: NativeProTheme.accent.opacity(0.08)
            )
    }
}

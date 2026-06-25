import SwiftUI

struct DetailView: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoadingDocument {
                LoadingDocumentView(title: model.documentTitle)
            } else if model.document == nil {
                EmptyDocumentView(openDocument: model.openDocument)
            } else {
                GeometryReader { proxy in
                    ZStack(alignment: .bottom) {
                        PDFKitRepresentedView(model: model)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: NativeProTheme.surfaceShadow.opacity(0.66), radius: 24, x: 0, y: 14)

                        ReaderCanvasControls(model: model, availableWidth: proxy.size.width)
                            .padding(.horizontal, 12)
                            .padding(.bottom, proxy.size.height < 560 ? 22 : 44)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            }
        }
        .background {
            ReaderCanvasBackground()
        }
        .navigationTitle(model.documentTitle)
    }
}

private struct ReaderCanvasBackground: View {
    var body: some View {
        NativeProTheme.readerCanvas.opacity(0.46)
    }
}

private struct ReaderCanvasControls: View {
    @ObservedObject var model: ReaderModel
    let availableWidth: CGFloat
    @Environment(\.appLanguage) private var language
    @SceneStorage("readerCanvasControls.isCollapsed") private var isCollapsed = false
    @State private var activeTool: CanvasTool = .select
    @State private var isSearchPresented = false

    var body: some View {
        let metrics = CanvasControlsMetrics(availableWidth: availableWidth)

        Group {
            if isCollapsed {
                collapsedHandle(metrics: metrics)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
            } else {
                expandedToolbar(metrics: metrics)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isCollapsed)
    }

    private func expandedToolbar(metrics: CanvasControlsMetrics) -> some View {
        HStack(spacing: 0) {
            toolButton(.select, systemImage: "cursorarrow", metrics: metrics)
            ToolbarDivider(height: metrics.dividerHeight)
            toolButton(.pan, systemImage: "hand.raised", metrics: metrics)
            ToolbarDivider(height: metrics.dividerHeight)
            actionButton("minus", metrics: metrics) {
                model.send(.zoomOut)
            }
            ToolbarDivider(height: metrics.dividerHeight)
            actionButton("plus.magnifyingglass", metrics: metrics) {
                model.send(.fitToView)
            }
            ToolbarDivider(height: metrics.dividerHeight)
            actionButton("plus", metrics: metrics) {
                model.send(.zoomIn)
            }
            ToolbarDivider(height: metrics.dividerHeight)
            searchButton(metrics: metrics)
            ToolbarDivider(height: metrics.dividerHeight)
            moreMenu(metrics: metrics)
            ToolbarDivider(height: metrics.dividerHeight)
            collapseButton(metrics: metrics)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(width: metrics.toolbarWidth, height: metrics.height)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.90),
            strokeColor: NativeProTheme.separator.opacity(0.54),
            isInteractive: true
        )
        .shadow(color: NativeProTheme.surfaceShadow.opacity(0.46), radius: 14, y: 8)
    }

    private func collapsedHandle(metrics: CanvasControlsMetrics) -> some View {
        Button {
            setCollapsed(false)
        } label: {
            Capsule(style: .continuous)
                .fill(NativeProTheme.accent.opacity(0.72))
                .frame(width: metrics.collapsedLineWidth, height: metrics.collapsedLineHeight)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.30), lineWidth: 0.6)
                }
                .frame(width: metrics.collapsedHitWidth, height: metrics.collapsedHitHeight)
                .contentShape(RoundedRectangle(cornerRadius: metrics.collapsedHitHeight / 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(language.text("toolbar.expandControls"))
        .accessibilityLabel(language.text("toolbar.expandControls"))
        .shadow(color: NativeProTheme.surfaceShadow.opacity(0.38), radius: 9, y: 5)
    }

    private func canvasButton(
        _ systemImage: String,
        isActive: Bool = false,
        width: CGFloat? = nil,
        metrics: CanvasControlsMetrics
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: metrics.iconSize, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.ink)
            .frame(width: width ?? metrics.buttonWidth, height: metrics.height)
            .contentShape(Rectangle())
    }

    private func toolButton(_ tool: CanvasTool, systemImage: String, metrics: CanvasControlsMetrics) -> some View {
        Button {
            activeTool = tool
        } label: {
            canvasButton(systemImage, isActive: activeTool == tool, metrics: metrics)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(tool.title)
    }

    private func actionButton(_ systemImage: String, metrics: CanvasControlsMetrics, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            canvasButton(systemImage, metrics: metrics)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func searchButton(metrics: CanvasControlsMetrics) -> some View {
        Button {
            isSearchPresented.toggle()
        } label: {
            canvasButton("magnifyingglass", isActive: isSearchPresented || !model.searchText.isEmpty, metrics: metrics)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(language.text("toolbar.search"))
        .popover(isPresented: $isSearchPresented, arrowEdge: .top) {
            CanvasSearchPopover(model: model)
        }
    }

    private func moreMenu(metrics: CanvasControlsMetrics) -> some View {
        Menu {
            Button(language.text("toolbar.fitPage")) {
                model.send(.fitToView)
            }
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.actualSize")) {
                model.send(.actualSize)
            }
            .disabled(!model.hasDocument)

            Divider()

            Button(language.text("toolbar.firstPage")) {
                model.send(.goToPage(0))
            }
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.lastPage")) {
                model.send(.goToPage(max(model.pageCount - 1, 0)))
            }
            .disabled(!model.hasDocument)
        } label: {
            canvasButton("ellipsis", metrics: metrics)
        }
        .menuStyle(.borderlessButton)
        .frame(width: metrics.buttonWidth, height: metrics.height)
        .contentShape(Rectangle())
        .help(language.text("toolbar.more"))
    }

    private func collapseButton(metrics: CanvasControlsMetrics) -> some View {
        Button {
            setCollapsed(true)
        } label: {
            canvasButton("chevron.compact.down", width: metrics.collapseButtonWidth, metrics: metrics)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(language.text("toolbar.collapseControls"))
        .accessibilityLabel(language.text("toolbar.collapseControls"))
    }

    private func setCollapsed(_ collapsed: Bool) {
        if collapsed {
            isSearchPresented = false
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            isCollapsed = collapsed
        }
    }
}

private struct CanvasControlsMetrics {
    let availableWidth: CGFloat

    private var buttonCount: CGFloat { 7 }
    private var dividerCount: CGFloat { 7 }

    var horizontalPadding: CGFloat {
        availableWidth < 520 ? 8 : 12
    }

    var toolbarWidth: CGFloat {
        let maximum = max(260, availableWidth - 28)
        let ideal = buttonCount * 46 + collapseButtonWidth + dividerCount + horizontalPadding * 2
        return min(ideal, maximum)
    }

    var buttonWidth: CGFloat {
        let availableButtonSpace = toolbarWidth - collapseButtonWidth - dividerCount - horizontalPadding * 2
        return min(46, max(36, floor(availableButtonSpace / buttonCount)))
    }

    var height: CGFloat {
        min(56, max(48, buttonWidth + 8))
    }

    var iconSize: CGFloat {
        min(19, max(16, buttonWidth * 0.38))
    }

    var dividerHeight: CGFloat {
        min(28, max(22, height * 0.46))
    }

    var cornerRadius: CGFloat {
        min(16, max(14, height * 0.30))
    }

    var collapseButtonWidth: CGFloat {
        availableWidth < 520 ? 24 : 26
    }

    var collapsedLineWidth: CGFloat {
        availableWidth < 520 ? 58 : 72
    }

    var collapsedLineHeight: CGFloat {
        5
    }

    var collapsedHitWidth: CGFloat {
        collapsedLineWidth + 26
    }

    var collapsedHitHeight: CGFloat {
        24
    }
}

private struct CanvasSearchPopover: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            searchField

            HStack(spacing: 10) {
                Text(matchLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                matchButton(title: language.text("toolbar.previousMatch"), systemImage: "chevron.up", action: model.selectPreviousSearchResult)
                    .disabled(model.searchResults.isEmpty)

                matchButton(title: language.text("toolbar.nextMatch"), systemImage: "chevron.down", action: model.selectNextSearchResult)
                    .disabled(model.searchResults.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(NativeProTheme.panel.opacity(0.96))
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(NativeProTheme.muted)

            TextField(language.text("toolbar.search"), text: $model.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .focused($isSearchFocused)
                .onSubmit {
                    model.selectNextSearchResult()
                }

            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(NativeProTheme.muted)
                .help(language.text("toolbar.clearSearch"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 13, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.90),
            strokeColor: NativeProTheme.separator.opacity(1.0),
            isInteractive: true
        )
    }

    private var matchLabel: String {
        String(format: language.text("toolbar.searchMatchesFormat"), model.searchLabel)
    }

    private func matchButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 30)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                    fallbackColor: NativeProTheme.tile.opacity(0.84),
                    strokeColor: NativeProTheme.separator.opacity(0.82),
                    isInteractive: true
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(NativeProTheme.ink)
        .help(title)
    }
}

private enum CanvasTool {
    case select
    case pan

    var title: String {
        switch self {
        case .select:
            return "Select"
        case .pan:
            return "Pan"
        }
    }
}

private struct ToolbarDivider: View {
    let height: CGFloat

    var body: some View {
        Rectangle()
            .fill(NativeProTheme.separator.opacity(0.70))
            .frame(width: 1, height: height)
    }
}

private struct LoadingDocumentView: View {
    let title: String
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 5) {
                Text(language.text("loadingPDF"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(NativeProTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderCanvasBackground())
    }
}

private struct EmptyDocumentView: View {
    let openDocument: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        ReadArcGlassContainer(spacing: 14) {
            VStack(spacing: 18) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 62, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(NativeProTheme.muted)
                    .frame(width: 94, height: 94)
                    .readArcGlass(
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                        fallbackColor: NativeProTheme.panel.opacity(0.34),
                        strokeColor: NativeProTheme.separator.opacity(0.50)
                    )

                VStack(spacing: 7) {
                    Text(language.text("empty.title"))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(NativeProTheme.ink)

                    Text(language.text("empty.subtitle"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NativeProTheme.muted)
                }

                Button {
                    openDocument()
                } label: {
                    Label(language.text("openPDF"), systemImage: "folder")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("o")
                .foregroundStyle(NativeProTheme.accent)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderCanvasBackground())
    }
}

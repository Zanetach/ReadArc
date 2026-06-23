import SwiftUI

struct ReaderToolbar: View {
    @ObservedObject var model: ReaderModel
    let isCollapsed: Bool
    let toggleCollapsed: () -> Void
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue

    var body: some View {
        GeometryReader { proxy in
            toolbarContent(width: proxy.size.width)
        }
        .frame(height: toolbarHeight)
        .background(NativeProTheme.header.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(height: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: isCollapsed)
    }

    private var toolbarHeight: CGFloat {
        if model.hasDocument && isCollapsed {
            return 36
        }
        return model.hasDocument ? 64 : 48
    }

    @ViewBuilder
    private func toolbarContent(width: CGFloat) -> some View {
        if model.hasDocument && isCollapsed {
            collapsedToolbarContent(width: width)
        } else if !model.hasDocument {
            emptyToolbarContent(width: width)
        } else if width < 980 {
            compactToolbarContent(width: width)
        } else {
            regularToolbarContent(width: width)
        }
    }

    private func collapsedToolbarContent(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            ToolbarIconButton(
                title: "Expand Toolbar",
                systemImage: "chevron.down",
                isDisabled: false
            ) {
                toggleCollapsed()
            }

            ToolbarMetricText(model.pageLabel, minWidth: 72)

            if width >= 620 {
                ToolbarMetricText(model.scaleLabel, minWidth: 54)
            }

            Spacer(minLength: 8)

            if width >= 760 {
                Text(model.documentTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: min(360, width * 0.35), alignment: .trailing)
            }

            ToolbarIconButton(
                title: model.isInspectorVisible && model.rightPanelMode == .inspector ? "Hide Inspector" : "Show Inspector",
                systemImage: "sidebar.trailing",
                isDisabled: false
            ) {
                model.toggleInspectorPanel()
            }
        }
        .padding(.horizontal, width < 680 ? 8 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyToolbarContent(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)

            ToolbarPreferenceSwitches(
                appearanceMode: appearanceMode,
                appLanguage: appLanguage,
                compact: width < 760
            )

            ToolbarIconButton(
                title: model.isInspectorVisible ? "Hide Inspector" : "Show Inspector",
                systemImage: "sidebar.trailing",
                isDisabled: false
            ) {
                model.toggleInspectorPanel()
            }
        }
        .padding(.horizontal, width < 680 ? 8 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func regularToolbarContent(width: CGFloat) -> some View {
        HStack(spacing: width < 720 ? 6 : 10) {
            leftGroup(compact: width < 620)
                .layoutPriority(2)

            if width >= 700 {
                Spacer(minLength: 6)
                centerGroup
            }

            Spacer(minLength: 6)

            rightGroup(width: width)
                .layoutPriority(3)
        }
        .padding(.horizontal, width < 680 ? 8 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactToolbarContent(width: CGFloat) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                leftGroup(compact: true)

                if width >= 760 {
                    centerGroup
                } else {
                    compactZoomGroup
                }

                Spacer(minLength: 6)

                ToolbarPreferenceSwitches(
                    appearanceMode: appearanceMode,
                    appLanguage: appLanguage,
                    compact: true
                )

                ToolbarIconButton(
                    title: model.isInspectorVisible ? "Hide Inspector" : "Show Inspector",
                    systemImage: "sidebar.trailing",
                    isDisabled: false
                ) {
                    model.toggleInspectorPanel()
                }

                ToolbarIconButton(
                    title: "Collapse Toolbar",
                    systemImage: "chevron.up",
                    isDisabled: false
                ) {
                    toggleCollapsed()
                }
            }

            HStack(spacing: 6) {
                ToolbarSearchField(
                    text: $model.searchText,
                    width: max(140, min(260, width - 270)),
                    isDisabled: !model.hasDocument
                ) {
                    model.selectNextSearchResult()
                }

                ToolbarMetricText(model.searchLabel, minWidth: 42)

                ToolbarIconButton(title: "Previous Match", systemImage: "chevron.up", isDisabled: model.searchResults.isEmpty) {
                    model.selectPreviousSearchResult()
                }

                ToolbarIconButton(title: "Next Match", systemImage: "chevron.down", isDisabled: model.searchResults.isEmpty) {
                    model.selectNextSearchResult()
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func leftGroup(compact: Bool) -> some View {
        HStack(spacing: 6) {
            ToolbarIconButton(title: "Previous Page", systemImage: "chevron.left", isDisabled: !model.hasDocument) {
                model.send(.previousPage)
            }

            ToolbarIconButton(title: "Next Page", systemImage: "chevron.right", isDisabled: !model.hasDocument) {
                model.send(.nextPage)
            }

            ToolbarMetricText(model.pageLabel, minWidth: compact ? 48 : 72)
        }
        .frame(minWidth: compact ? 104 : 136, alignment: .leading)
    }

    private var centerGroup: some View {
        HStack(spacing: 6) {
            ToolbarIconButton(title: "Zoom Out", systemImage: "minus.magnifyingglass", isDisabled: !model.hasDocument) {
                model.send(.zoomOut)
            }

            ToolbarMetricText(model.scaleLabel, minWidth: 54)

            ToolbarIconButton(title: "Zoom In", systemImage: "plus.magnifyingglass", isDisabled: !model.hasDocument) {
                model.send(.zoomIn)
            }

            ToolbarIconButton(title: "Fit Page", systemImage: "arrow.up.left.and.arrow.down.right", isDisabled: !model.hasDocument) {
                model.send(.fitToView)
            }
        }
    }

    private var compactZoomGroup: some View {
        HStack(spacing: 5) {
            ToolbarIconButton(title: "Zoom Out", systemImage: "minus.magnifyingglass", isDisabled: !model.hasDocument) {
                model.send(.zoomOut)
            }

            ToolbarMetricText(model.scaleLabel, minWidth: 44)

            ToolbarIconButton(title: "Zoom In", systemImage: "plus.magnifyingglass", isDisabled: !model.hasDocument) {
                model.send(.zoomIn)
            }

            ToolbarIconButton(title: "Fit Page", systemImage: "arrow.up.left.and.arrow.down.right", isDisabled: !model.hasDocument) {
                model.send(.fitToView)
            }
        }
    }

    private func rightGroup(width: CGFloat) -> some View {
        HStack(spacing: 6) {
            ToolbarSearchField(
                text: $model.searchText,
                width: searchFieldWidth(for: width),
                isDisabled: !model.hasDocument
            ) {
                model.selectNextSearchResult()
            }

            if width >= 560 {
                ToolbarMetricText(model.searchLabel, minWidth: 42)
            }

            if width >= 650 {
                ToolbarIconButton(title: "Previous Match", systemImage: "chevron.up", isDisabled: model.searchResults.isEmpty) {
                    model.selectPreviousSearchResult()
                }

                ToolbarIconButton(title: "Next Match", systemImage: "chevron.down", isDisabled: model.searchResults.isEmpty) {
                    model.selectNextSearchResult()
                }
            }

            ToolbarPreferenceSwitches(
                appearanceMode: appearanceMode,
                appLanguage: appLanguage,
                compact: width < 760
            )

            ToolbarIconButton(
                title: model.isInspectorVisible && model.rightPanelMode == .inspector ? "Hide Inspector" : "Show Inspector",
                systemImage: "sidebar.trailing",
                isDisabled: false
            ) {
                model.toggleInspectorPanel()
            }

            ToolbarIconButton(
                title: "Collapse Toolbar",
                systemImage: "chevron.up",
                isDisabled: false
            ) {
                toggleCollapsed()
            }
        }
        .frame(minWidth: 0, alignment: .trailing)
    }

    private func searchFieldWidth(for width: CGFloat) -> CGFloat {
        if width < 620 {
            return 92
        }
        if width < 820 {
            return 126
        }
        return 166
    }

    private var appearanceMode: Binding<AppAppearanceMode> {
        Binding(
            get: { AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    private var appLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRaw) ?? .system },
            set: { languageRaw = $0.rawValue }
        )
    }
}

private struct ToolbarIconButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
                .background(NativeProTheme.panel.opacity(0.62), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(NativeProTheme.separator, lineWidth: 1)
                }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .foregroundStyle(NativeProTheme.ink)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct ToolbarMetricText: View {
    let text: String
    let minWidth: CGFloat

    init(_ text: String, minWidth: CGFloat) {
        self.text = text
        self.minWidth = minWidth
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(NativeProTheme.muted)
            .frame(minWidth: minWidth)
            .padding(.horizontal, 7)
            .frame(height: 23)
            .background(NativeProTheme.tile.opacity(0.58), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct ToolbarSearchField: View {
    @Binding var text: String
    let width: CGFloat
    let isDisabled: Bool
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NativeProTheme.muted)

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: width)
                .disabled(isDisabled)
                .onSubmit(submit)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(NativeProTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(NativeProTheme.separator, lineWidth: 1)
        }
        .opacity(isDisabled ? 0.48 : 1)
    }
}

private struct ToolbarPreferenceSwitches: View {
    @Binding var appearanceMode: AppAppearanceMode
    @Binding var appLanguage: AppLanguage
    let compact: Bool
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ToolbarSegmentButton(
                    title: language.text("appearance.system"),
                    systemImage: "circle.lefthalf.filled",
                    text: nil,
                    isActive: appearanceMode == .system
                ) {
                    setAppearanceMode(.system)
                }

                ToolbarSegmentButton(
                    title: language.text("appearance.light"),
                    systemImage: "sun.max",
                    text: nil,
                    isActive: appearanceMode == .light
                ) {
                    setAppearanceMode(.light)
                }

                ToolbarSegmentButton(
                    title: language.text("appearance.dark"),
                    systemImage: "moon",
                    text: nil,
                    isActive: appearanceMode == .dark
                ) {
                    setAppearanceMode(.dark)
                }
            }
            .padding(2)
            .background(NativeProTheme.tile.opacity(0.62), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(NativeProTheme.separator, lineWidth: 1)
            }
            .help(language.text("appearance"))

            HStack(spacing: 2) {
                ToolbarSegmentButton(
                    title: language.text("language.chinese"),
                    systemImage: nil,
                    text: "中",
                    isActive: appLanguage.resolved == .simplifiedChinese
                ) {
                    appLanguage = .simplifiedChinese
                }

                ToolbarSegmentButton(
                    title: language.text("language.english"),
                    systemImage: nil,
                    text: "EN",
                    isActive: appLanguage.resolved == .english
                ) {
                    appLanguage = .english
                }
            }
            .padding(2)
            .background(NativeProTheme.tile.opacity(0.62), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(NativeProTheme.separator, lineWidth: 1)
            }
            .help(language.text("language"))
        }
    }

    private func setAppearanceMode(_ mode: AppAppearanceMode) {
        appearanceMode = mode
        AppAppearanceController.apply(mode)
        if mode == .system {
            AppAppearanceController.requestSystemAppearanceRefresh()
        }
    }
}

private struct ToolbarSegmentButton: View {
    let title: String
    let systemImage: String?
    let text: String?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                } else if let text {
                    Text(text)
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .frame(width: text == nil ? 24 : 28, height: 20)
            .foregroundStyle(isActive ? NativeProTheme.primaryButtonText : NativeProTheme.muted)
            .background(isActive ? NativeProTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

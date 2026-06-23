import AppKit
import SwiftUI

struct ReaderToolbar: View {
    @ObservedObject var model: ReaderModel
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
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    NSApp.keyWindow?.performZoom(nil)
                }
        )
    }

    private var toolbarHeight: CGFloat {
        return 72
    }

    @ViewBuilder
    private func toolbarContent(width: CGFloat) -> some View {
        if width < 980 {
            compactToolbarContent(width: width)
        } else {
            regularToolbarContent(width: width)
        }
    }

    private func regularToolbarContent(width: CGFloat) -> some View {
        HStack(spacing: width < 720 ? 8 : 12) {
            Color.clear
                .frame(width: 68)

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
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Color.clear
                    .frame(width: 64)

                leftGroup(compact: true)

                if width >= 760 {
                    centerGroup
                } else {
                    compactZoomGroup
                }

                Spacer(minLength: 6)

                ToolbarIconButton(
                    title: model.isInspectorVisible ? "Hide Panel" : "Show Panel",
                    systemImage: "sidebar.trailing",
                    isDisabled: false
                ) {
                    model.toggleInspectorPanel()
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
        HStack(spacing: 8) {
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
        HStack(spacing: 8) {
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
        HStack(spacing: 8) {
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

            ToolbarIconButton(
                title: model.isInspectorVisible ? "Hide Panel" : "Show Panel",
                systemImage: "sidebar.trailing",
                isDisabled: false
            ) {
                model.toggleInspectorPanel()
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
                .frame(width: 42, height: 42)
                .background(NativeProTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NativeProTheme.separator.opacity(1.25), lineWidth: 1)
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
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(NativeProTheme.tile.opacity(0.74), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
        .frame(height: 42)
        .background(NativeProTheme.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(NativeProTheme.separator.opacity(1.2), lineWidth: 1)
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
            .frame(height: 40)
            .background(NativeProTheme.tile.opacity(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            .frame(height: 40)
            .background(NativeProTheme.tile.opacity(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            .frame(width: text == nil ? 28 : 32, height: 28)
            .foregroundStyle(isActive ? NativeProTheme.primaryButtonText : NativeProTheme.muted)
            .background(isActive ? NativeProTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

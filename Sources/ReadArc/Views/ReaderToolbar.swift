import AppKit
import SwiftUI

struct ReaderToolbar: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language

    var body: some View {
        GeometryReader { proxy in
            ReadArcGlassContainer(spacing: proxy.size.width < 720 ? 8 : 12) {
                toolbarContent(width: proxy.size.width)
            }
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
        return 64
    }

    @ViewBuilder
    private func toolbarContent(width: CGFloat) -> some View {
        if model.hasDocument {
            regularToolbarContent(width: width)
        } else {
            emptyToolbarContent(width: width)
        }
    }

    private func regularToolbarContent(width: CGFloat) -> some View {
        ZStack {
            HStack(spacing: width < 720 ? 8 : 12) {
                Color.clear
                    .frame(width: 66)

                leftGroup(compact: width < 620)
                    .layoutPriority(2)

                Spacer(minLength: 16)

                rightGroup(width: width)
                    .layoutPriority(3)
            }

            if width >= 1220 {
                centerGroup(width: width)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, width < 680 ? 8 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyToolbarContent(width: CGFloat) -> some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 66)

            Spacer(minLength: 0)

            ToolbarIconButton(
                title: model.isInspectorVisible ? language.text("toolbar.hidePanel") : language.text("toolbar.showPanel"),
                systemImage: "sidebar.trailing",
                isDisabled: false
            ) {
                model.toggleInspectorPanel()
            }
        }
        .padding(.horizontal, width < 680 ? 8 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func leftGroup(compact: Bool) -> some View {
        HStack(spacing: 8) {
            ToolbarIconButton(title: language.text("toolbar.previousPage"), systemImage: "chevron.left", isDisabled: !model.hasDocument) {
                model.send(.previousPage)
            }

            ToolbarIconButton(title: language.text("toolbar.nextPage"), systemImage: "chevron.right", isDisabled: !model.hasDocument) {
                model.send(.nextPage)
            }

            ToolbarMetricText(model.pageLabel, minWidth: compact ? 48 : 72)
        }
        .frame(minWidth: compact ? 104 : 136, alignment: .leading)
    }

    @ViewBuilder
    private func centerGroup(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            if width >= 900 {
                ToolbarIconButton(title: language.text("toolbar.zoomOut"), systemImage: "minus.magnifyingglass", isDisabled: !model.hasDocument) {
                    model.send(.zoomOut)
                }
            }

            ToolbarMetricText(model.scaleLabel, minWidth: 54)

            ToolbarIconButton(title: language.text("toolbar.zoomIn"), systemImage: "plus.magnifyingglass", isDisabled: !model.hasDocument) {
                model.send(.zoomIn)
            }

            if width >= 1050 {
                ToolbarIconButton(title: language.text("toolbar.fitPage"), systemImage: "arrow.up.left.and.arrow.down.right", isDisabled: !model.hasDocument) {
                    model.send(.fitToView)
                }
            }
        }
    }

    private func rightGroup(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            if width >= 860 {
                ToolbarSearchField(
                    text: $model.searchText,
                    placeholder: language.text("toolbar.search"),
                    width: searchFieldWidth(for: width),
                    isDisabled: !model.hasDocument
                ) {
                    model.selectNextSearchResult()
                }
            } else if model.hasDocument {
                ToolbarIconButton(title: language.text("toolbar.search"), systemImage: "magnifyingglass", isDisabled: false) {
                    model.showResearch(tab: .search)
                }
            }

            if width >= 760 {
                ToolbarMetricText(model.searchLabel, minWidth: 42)
            }

            if width >= 980 {
                ToolbarIconButton(title: language.text("toolbar.previousMatch"), systemImage: "chevron.up", isDisabled: model.searchResults.isEmpty) {
                    model.selectPreviousSearchResult()
                }

                ToolbarIconButton(title: language.text("toolbar.nextMatch"), systemImage: "chevron.down", isDisabled: model.searchResults.isEmpty) {
                    model.selectNextSearchResult()
                }
            }

            if width < 1220 {
                ToolbarOverflowMenu(model: model, showsSearchNavigation: width < 980)
            }

            ToolbarIconButton(
                title: model.isInspectorVisible ? language.text("toolbar.hidePanel") : language.text("toolbar.showPanel"),
                systemImage: "sidebar.trailing",
                isDisabled: false
            ) {
                model.toggleInspectorPanel()
            }

        }
        .frame(minWidth: 0, alignment: .trailing)
    }

    private func searchFieldWidth(for width: CGFloat) -> CGFloat {
        if width < 980 {
            return 120
        }
        if width < 1180 {
            return 150
        }
        return 220
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
                .frame(width: 38, height: 38)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                    fallbackColor: NativeProTheme.panel.opacity(0.86),
                    strokeColor: NativeProTheme.separator.opacity(1.25),
                    isInteractive: true
                )
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
            .frame(height: 36)
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 11, style: .continuous),
                fallbackColor: NativeProTheme.tile.opacity(0.74),
                strokeColor: NativeProTheme.separator.opacity(0.65)
            )
    }
}

private struct ToolbarSearchField: View {
    @Binding var text: String
    let placeholder: String
    let width: CGFloat
    let isDisabled: Bool
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NativeProTheme.muted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: width)
                .disabled(isDisabled)
                .onSubmit(submit)
        }
        .padding(.horizontal, 9)
        .frame(height: 38)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 11, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.82),
            strokeColor: NativeProTheme.separator.opacity(1.2),
            isInteractive: true
        )
        .opacity(isDisabled ? 0.48 : 1)
    }
}

private struct ToolbarOverflowMenu: View {
    @ObservedObject var model: ReaderModel
    let showsSearchNavigation: Bool
    @Environment(\.appLanguage) private var language

    var body: some View {
        Menu {
            Button(language.text("toolbar.zoomOut")) {
                model.send(.zoomOut)
            }
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.zoomIn")) {
                model.send(.zoomIn)
            }
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.fitPage")) {
                model.send(.fitToView)
            }
            .disabled(!model.hasDocument)

            if showsSearchNavigation {
                Divider()

                Button(language.text("toolbar.previousMatch")) {
                    model.selectPreviousSearchResult()
                }
                .disabled(model.searchResults.isEmpty)

                Button(language.text("toolbar.nextMatch")) {
                    model.selectNextSearchResult()
                }
                .disabled(model.searchResults.isEmpty)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 38, height: 38)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                    fallbackColor: NativeProTheme.panel.opacity(0.86),
                    strokeColor: NativeProTheme.separator.opacity(1.25),
                    isInteractive: true
                )
                .foregroundStyle(NativeProTheme.ink)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 38, height: 38)
        .help(language.text("toolbar.more"))
        .accessibilityLabel(language.text("toolbar.more"))
    }
}

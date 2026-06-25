import AppKit
import SwiftUI

struct ReaderToolbar: View {
    @ObservedObject var model: ReaderModel
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue
    @Environment(\.appLanguage) private var language

    var body: some View {
        GeometryReader { proxy in
            ReadArcGlassContainer(spacing: proxy.size.width < 720 ? 8 : 12) {
                toolbarContent(width: proxy.size.width)
            }
        }
        .frame(height: toolbarHeight)
        .background(WindowDoubleClickZoomRegion())
    }

    private var toolbarHeight: CGFloat {
        return 76
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
        HStack(spacing: toolbarSpacing(for: width)) {
            toolbarBrand(width: width)
                .layoutPriority(4)

            Spacer(minLength: 8)

            utilityGroup(width: width)
                .layoutPriority(4)
        }
        .padding(.leading, width < 960 ? 12 : 34)
        .padding(.trailing, width < 960 ? 12 : 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyToolbarContent(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            toolbarBrand(width: width)

            Spacer(minLength: 0)

            ToolbarIconButton(
                title: model.isInspectorVisible ? language.text("toolbar.hidePanel") : language.text("toolbar.showPanel"),
                systemImage: "sidebar.trailing",
                isDisabled: false
            ) {
                model.toggleInspectorPanel()
            }
        }
        .padding(.leading, width < 960 ? 12 : 34)
        .padding(.trailing, width < 960 ? 12 : 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toolbarBrand(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: width >= 1800 ? 88 : (width >= 1200 ? 74 : 58))

            if model.hasDocument && width >= 820 {
                Text(model.documentTitle)
                    .font(.system(size: width >= 1800 ? 27 : 23, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(width: width >= 1800 ? 520 : (width >= 1200 ? 420 : (width >= 820 ? 300 : 64)), alignment: .leading)
    }

    private var pageGroup: some View {
        HStack(spacing: 0) {
            ToolbarSegmentButton(title: language.text("toolbar.previousPage"), systemImage: "chevron.left", isDisabled: !model.hasDocument) {
                model.send(.previousPage)
            }

            ToolbarDivider()

            Text(model.pageLabel)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(NativeProTheme.ink)
                .frame(width: 92)
                .frame(maxHeight: .infinity)

            ToolbarDivider()

            ToolbarSegmentButton(title: language.text("toolbar.nextPage"), systemImage: "chevron.right", isDisabled: !model.hasDocument) {
                model.send(.nextPage)
            }
        }
        .frame(width: 232, height: 62)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.90),
            strokeColor: NativeProTheme.separator.opacity(1.0),
            isInteractive: true
        )
    }

    private var viewGroup: some View {
        HStack(spacing: 0) {
            ToolbarSegmentButton(title: language.text("toolbar.zoomOut"), systemImage: "minus", isDisabled: !model.hasDocument) {
                model.send(.zoomOut)
            }

            ToolbarDivider()

            Text(model.scaleLabel)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(NativeProTheme.ink)
                .frame(width: 82)
                .frame(maxHeight: .infinity)

            ToolbarDivider()

            ToolbarSegmentButton(title: language.text("toolbar.zoomIn"), systemImage: "plus", isDisabled: !model.hasDocument) {
                model.send(.zoomIn)
            }

            ToolbarDivider()

            ToolbarSegmentButton(title: "Zoom Menu", systemImage: "chevron.down", isDisabled: !model.hasDocument) {
                model.send(.actualSize)
            }

            ToolbarDivider()

            ToolbarSegmentButton(title: language.text("toolbar.fitPage"), systemImage: "arrow.up.left.and.arrow.down.right", isDisabled: !model.hasDocument) {
                model.send(.fitToView)
            }
        }
        .frame(width: 298, height: 62)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.90),
            strokeColor: NativeProTheme.separator.opacity(1.0),
            isInteractive: true
        )
    }

    private func utilityGroup(width: CGFloat) -> some View {
        HStack(spacing: 12) {
            if width < 760 {
                ToolbarOverflowMenu(model: model, showsSearchNavigation: false)
            }

            if width >= 1100 {
                ToolbarAgentButton(selectedAgent: $model.selectedChatAgent)
                ToolbarLanguageButton(appLanguage: appLanguage)
                ToolbarAppearanceButton(appearanceMode: appearanceMode)
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

    private func toolbarSpacing(for width: CGFloat) -> CGFloat {
        width < 1200 ? 10 : 18
    }

    private var appearanceMode: Binding<AppAppearanceMode> {
        Binding(
            get: { AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system },
            set: { mode in
                appearanceModeRaw = mode.rawValue
                AppAppearanceController.apply(mode)
                if mode == .system {
                    AppAppearanceController.requestSystemAppearanceRefresh()
                }
            }
        )
    }

    private var appLanguage: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRaw) ?? .system },
            set: { languageRaw = $0.rawValue }
        )
    }
}

private struct ToolbarSegmentButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .foregroundStyle(NativeProTheme.ink)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(NativeProTheme.separator.opacity(0.88))
            .frame(width: 1, height: 34)
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
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 62, height: 62)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(NativeProTheme.ink)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct ToolbarAgentButton: View {
    @Binding var selectedAgent: ChatAgentProvider
    @State private var availability: AgentAvailability = .checking

    var body: some View {
        Menu {
            agentButton(.claudeCode)
            agentButton(.codexCLI)
        } label: {
            ZStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Circle()
                    .fill(isActive ? NativeProTheme.accent : NativeProTheme.faint.opacity(0.70))
                    .frame(width: 7, height: 7)
                    .offset(x: 14, y: -14)
            }
            .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.faint)
            .frame(width: 48, height: 52)
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                fallbackColor: NativeProTheme.panel.opacity(0.90),
                strokeColor: isActive ? NativeProTheme.accent.opacity(0.22) : NativeProTheme.separator.opacity(1.0),
                isInteractive: true
            )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 52, height: 58)
        .help(isActive ? selectedAgent.pickerTitle : "Agent unavailable")
        .accessibilityLabel("Agent")
        .task(id: selectedAgent) {
            await refreshAvailability()
        }
    }

    @ViewBuilder
    private func agentButton(_ agent: ChatAgentProvider) -> some View {
        Button {
            selectedAgent = agent
            availability = .checking
        } label: {
            HStack(spacing: 8) {
                AgentLogoView(agent: agent, size: 18)
                Text(agent.pickerTitle)

                if selectedAgent == agent {
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    private var isActive: Bool {
        availability == .available
    }

    @MainActor
    private func refreshAvailability() async {
        availability = await AgentStreamingService.cachedAvailability(for: selectedAgent)
    }
}

private struct ToolbarAppearanceButton: View {
    @Binding var appearanceMode: AppAppearanceMode
    @Environment(\.appLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Menu {
            Button {
                appearanceMode = .system
            } label: {
                Label(language.text("appearance.system"), systemImage: appearanceMode == .system ? "checkmark" : "circle.lefthalf.filled")
            }

            Button {
                appearanceMode = .light
            } label: {
                Label(language.text("appearance.light"), systemImage: appearanceMode == .light ? "checkmark" : "sun.max")
            }

            Button {
                appearanceMode = .dark
            } label: {
                Label(language.text("appearance.dark"), systemImage: appearanceMode == .dark ? "checkmark" : "moon")
            }
        } label: {
            Image(systemName: activeAppearanceIcon)
                .font(.system(size: 18, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 52, height: 58)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                    fallbackColor: NativeProTheme.panel.opacity(0.90),
                    strokeColor: NativeProTheme.separator.opacity(1.0),
                    isInteractive: true
                )
                .foregroundStyle(NativeProTheme.ink)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 52, height: 58)
        .help(language.text("appearance"))
        .accessibilityLabel(language.text("appearance"))
    }

    private var activeAppearanceIcon: String {
        switch appearanceMode {
        case .system:
            return colorScheme == .dark ? "moon" : "sun.max"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}

private struct ToolbarLanguageButton: View {
    @Binding var appLanguage: AppLanguage
    @Environment(\.appLanguage) private var language

    var body: some View {
        Menu {
            Button {
                appLanguage = .system
            } label: {
                Label(language.text("language.system"), systemImage: appLanguage == .system ? "checkmark" : "globe")
            }

            Button {
                appLanguage = .simplifiedChinese
            } label: {
                Label(language.text("language.chinese"), systemImage: appLanguage == .simplifiedChinese ? "checkmark" : "character.bubble")
            }

            Button {
                appLanguage = .english
            } label: {
                Label(language.text("language.english"), systemImage: appLanguage == .english ? "checkmark" : "textformat")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .medium))
                Text(languageButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(NativeProTheme.ink)
            .frame(width: 88, height: 58)
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                fallbackColor: NativeProTheme.panel.opacity(0.90),
                strokeColor: NativeProTheme.separator.opacity(1.0),
                isInteractive: true
            )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 88, height: 58)
        .help(language.text("language"))
        .accessibilityLabel(language.text("language"))
    }

    private var languageButtonTitle: String {
        switch appLanguage.resolved {
        case .simplifiedChinese:
            return "中"
        case .english, .system:
            return "EN"
        }
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

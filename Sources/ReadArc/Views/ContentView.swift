import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ReaderModel
    @State private var isDropTargeted = false
    @State private var leftSidebarDragStartWidth: CGFloat?
    @State private var rightPanelDragStartWidth: CGFloat?
    @SceneStorage("readArcLeftSidebarWidth") private var preferredLeftSidebarWidth: Double = 0
    @SceneStorage("readArcRightPanelWidth") private var preferredRightPanelWidth: Double = 0
    @Environment(\.appLanguage) private var language

    var body: some View {
        Group {
            if ReferencePreviewMode.isEnabled {
                ReferencePreviewView()
            } else {
                liveReaderBody
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .dropDestination(for: URL.self) { urls, _ in
            openDroppedPDF(from: urls)
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .overlay {
            if isDropTargeted {
                DropTargetOverlay()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !ReferencePreviewMode.isEnabled {
                WindowResizeGrip()
            }
        }
        .tint(NativeProTheme.accent)
        .background {
            NativeProTheme.window
        }
        .alert(language.text("openPDF.error.title"), isPresented: errorBinding) {
            Button(language.text("updates.ok")) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var liveReaderBody: some View {
        GeometryReader { proxy in
            let layout = ResponsiveReaderLayout(width: proxy.size.width, height: proxy.size.height)
            let shellInset: CGFloat = 0
            let leftSidebarVisible = (layout.showsSidebar && model.isSidebarVisible) || model.isLibraryOverlayVisible
            let leftSidebarWidth = layout.leftSidebarWidth(
                preferredWidth: preferredLeftSidebarWidth,
                sidebarVisible: leftSidebarVisible
            )
            let rightPanelWidth = layout.rightPanelWidth(
                preferredWidth: preferredRightPanelWidth,
                leftSidebarWidth: leftSidebarWidth,
                sidebarVisible: leftSidebarVisible,
                libraryOverlayVisible: model.isLibraryOverlayVisible
            )

            ZStack {
                ReadArcAmbientBackground()

                VStack(spacing: 0) {
                    ReaderToolbar(model: model)

                    HStack(spacing: layout.contentSpacing) {
                        CommandRailView(model: model, usesSidebarCollapse: layout.showsSidebar)
                            .frame(width: layout.railWidth)

                        if leftSidebarVisible {
                            ZStack(alignment: .trailing) {
                                leftSidebar
                                    .frame(width: leftSidebarWidth)

                                SidebarResizeHandle(
                                    isActive: leftSidebarDragStartWidth != nil,
                                    onChanged: { translation in
                                        resizeLeftSidebar(
                                            translation: translation,
                                            currentWidth: leftSidebarWidth,
                                            layout: layout
                                        )
                                    },
                                    onEnded: {
                                        leftSidebarDragStartWidth = nil
                                    }
                                )
                            }
                            .frame(width: leftSidebarWidth)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        DetailView(model: model)
                            .frame(minWidth: 0, maxWidth: .infinity)

                        if model.isInspectorVisible {
                            ZStack(alignment: .leading) {
                                rightPanel
                                    .frame(width: rightPanelWidth)

                                RightPanelResizeHandle(
                                    isActive: rightPanelDragStartWidth != nil,
                                    onChanged: { translation in
                                        resizeRightPanel(
                                            translation: translation,
                                            currentWidth: rightPanelWidth,
                                            layout: layout
                                        )
                                    },
                                    onEnded: {
                                        rightPanelDragStartWidth = nil
                                    }
                                )
                            }
                            .frame(width: rightPanelWidth)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.leading, layout.contentLeadingPadding)
                    .padding(.trailing, layout.contentTrailingPadding)
                    .padding(.bottom, layout.contentBottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: shellInset == 0 ? 0 : 22, style: .continuous),
                    fallbackColor: NativeProTheme.window.opacity(0.96),
                    strokeColor: NativeProTheme.separator.opacity(0.70),
                    fallbackStrokeWidth: shellInset == 0 ? 0 : 1
                )
                .clipShape(RoundedRectangle(cornerRadius: shellInset == 0 ? 0 : 22, style: .continuous))
                .shadow(color: .black.opacity(shellInset == 0 ? 0 : 0.14), radius: 20, x: 0, y: 14)
                .padding(shellInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var leftSidebar: some View {
        if model.hasDocument && !model.isLibraryOverlayVisible {
            PDFPageThumbnailPanel(model: model)
        } else {
            SidebarView(
                recents: model.recents,
                selectedURL: model.documentURL,
                readerMode: model.readerMode,
                openDocument: model.openDocument,
                openRecent: model.openRecent,
                removeRecent: model.removeRecent,
                clearRecents: model.clearRecents,
                configureLibraryFolder: model.configureLibraryFolder,
                libraryFolderName: model.libraryFolderDisplayName
            )
        }
    }

    @ViewBuilder
    private var rightPanel: some View {
        VStack(spacing: 0) {
            Group {
                switch model.rightPanelMode {
                case .chat:
                    AgentChatView(
                        model: model,
                        modeSwitcher: AnyView(RightPanelModeSwitcher(selectedMode: model.rightPanelMode, selectMode: model.showRightPanel))
                    )
                case .focus, .research:
                    DocumentInspectorView(
                        model: model,
                        modeSwitcher: AnyView(RightPanelModeSwitcher(selectedMode: model.rightPanelMode, selectMode: model.showRightPanel))
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .padding(.trailing, 10)
    }

    private func openDroppedPDF(from urls: [URL]) -> Bool {
        guard let pdfURL = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
            model.errorMessage = language.text("openPDF.error.dropNotPDF")
            return false
        }

        model.openDocumentsInWindows([pdfURL])
        return true
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.errorMessage = nil
                }
            }
        )
    }

    private func resizeRightPanel(
        translation: CGFloat,
        currentWidth: CGFloat,
        layout: ResponsiveReaderLayout
    ) {
        if rightPanelDragStartWidth == nil {
            rightPanelDragStartWidth = currentWidth
        }

        let startWidth = rightPanelDragStartWidth ?? currentWidth
        let proposedWidth = startWidth - translation
        let clampedWidth = layout.clampedRightPanelWidth(
            proposedWidth,
            leftSidebarWidth: layout.leftSidebarWidth(
                preferredWidth: preferredLeftSidebarWidth,
                sidebarVisible: (layout.showsSidebar && model.isSidebarVisible) || model.isLibraryOverlayVisible
            ),
            sidebarVisible: (layout.showsSidebar && model.isSidebarVisible) || model.isLibraryOverlayVisible,
            libraryOverlayVisible: model.isLibraryOverlayVisible
        )
        preferredRightPanelWidth = Double(clampedWidth)
    }

    private func resizeLeftSidebar(
        translation: CGFloat,
        currentWidth: CGFloat,
        layout: ResponsiveReaderLayout
    ) {
        if leftSidebarDragStartWidth == nil {
            leftSidebarDragStartWidth = currentWidth
        }

        let startWidth = leftSidebarDragStartWidth ?? currentWidth
        let proposedWidth = startWidth + translation
        let clampedWidth = layout.clampedLeftSidebarWidth(
            proposedWidth,
            rightPanelVisible: model.isInspectorVisible,
            preferredRightPanelWidth: preferredRightPanelWidth
        )
        preferredLeftSidebarWidth = Double(clampedWidth)
    }
}

private struct ReadArcAmbientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                NativeProTheme.window,
                Color(red: 0.945, green: 0.976, blue: 1.000),
                Color(red: 0.965, green: 0.982, blue: 1.000)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct ResponsiveReaderLayout {
    let width: CGFloat
    let height: CGFloat

    var railWidth: CGFloat {
        CommandRailMetrics.slotWidth(for: height, windowWidth: width)
    }

    var showsSidebar: Bool {
        width >= 900
    }

    var defaultSidebarWidth: CGFloat {
        if width < 1060 {
            return 230
        }
        if width < 1400 {
            return 260
        }
        if width < 1800 {
            return 290
        }
        return 320
    }

    var minSidebarWidth: CGFloat {
        width < 1060 ? 210 : 240
    }

    var contentSpacing: CGFloat {
        if width < 1100 {
            return 12
        }
        if width < 1500 {
            return 16
        }
        return 22
    }

    var contentLeadingPadding: CGFloat {
        if width < 1100 {
            return 18
        }
        return width < 1500 ? 26 : 34
    }

    var contentTrailingPadding: CGFloat {
        if width < 1100 {
            return 16
        }
        return width < 1500 ? 22 : 28
    }

    var contentBottomPadding: CGFloat {
        height < 680 ? 18 : 28
    }

    func leftSidebarWidth(
        preferredWidth: Double,
        sidebarVisible: Bool
    ) -> CGFloat {
        guard sidebarVisible else { return 0 }
        let preferred = preferredWidth > 0 ? CGFloat(preferredWidth) : defaultSidebarWidth
        return clampedLeftSidebarWidth(preferred)
    }

    func clampedLeftSidebarWidth(
        _ proposedWidth: CGFloat,
        rightPanelVisible: Bool = false,
        preferredRightPanelWidth: Double = 0
    ) -> CGFloat {
        min(max(proposedWidth, minSidebarWidth), maxLeftSidebarWidth(rightPanelVisible: rightPanelVisible, preferredRightPanelWidth: preferredRightPanelWidth))
    }

    var defaultRightPanelWidth: CGFloat {
        if width < 1060 {
            return 270
        }
        if width < 1400 {
            return 310
        }
        if width < 1800 {
            return 350
        }
        return 390
    }

    var minRightPanelWidth: CGFloat {
        width < 1060 ? 250 : 290
    }

    func rightPanelWidth(
        preferredWidth: Double,
        leftSidebarWidth: CGFloat,
        sidebarVisible: Bool,
        libraryOverlayVisible: Bool
    ) -> CGFloat {
        let preferred = preferredWidth > 0 ? CGFloat(preferredWidth) : defaultRightPanelWidth
        return clampedRightPanelWidth(
            preferred,
            leftSidebarWidth: leftSidebarWidth,
            sidebarVisible: sidebarVisible,
            libraryOverlayVisible: libraryOverlayVisible
        )
    }

    func clampedRightPanelWidth(
        _ proposedWidth: CGFloat,
        leftSidebarWidth: CGFloat = 0,
        sidebarVisible: Bool = false,
        libraryOverlayVisible: Bool = false
    ) -> CGFloat {
        min(max(proposedWidth, minRightPanelWidth), maxRightPanelWidth(leftSidebarWidth: leftSidebarWidth, sidebarVisible: sidebarVisible, libraryOverlayVisible: libraryOverlayVisible))
    }

    private func maxLeftSidebarWidth(rightPanelVisible: Bool, preferredRightPanelWidth: Double) -> CGFloat {
        let rightWidth = rightPanelVisible
            ? (preferredRightPanelWidth > 0 ? CGFloat(preferredRightPanelWidth) : defaultRightPanelWidth)
            : 0
        let minReaderWidth: CGFloat = width < 1060 ? 300 : 420
        let chrome = contentLeadingPadding + contentTrailingPadding + contentSpacing * 3
        let available = width - railWidth - rightWidth - minReaderWidth - chrome
        return max(minSidebarWidth, min(360, available))
    }

    private func maxRightPanelWidth(leftSidebarWidth: CGFloat, sidebarVisible: Bool, libraryOverlayVisible: Bool) -> CGFloat {
        let sidebarIsShown = (showsSidebar && sidebarVisible) || libraryOverlayVisible
        let chrome = contentLeadingPadding + contentTrailingPadding + contentSpacing * 3
        let occupiedWidth = railWidth + (sidebarIsShown ? leftSidebarWidth : 0) + chrome
        let minReaderWidth: CGFloat = width < 1060 ? 300 : 420
        let available = width - occupiedWidth - minReaderWidth
        return max(minRightPanelWidth, min(440, available))
    }
}

private struct SidebarResizeHandle: View {
    let isActive: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 12)
            .overlay {
                Capsule()
                    .fill(handleColor)
                    .frame(width: (isHovering || isActive) ? 4 : 2)
                    .opacity((isHovering || isActive) ? 1 : 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onChanged(value.translation.width)
                    }
                    .onEnded { _ in
                        onEnded()
                    }
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .accessibilityLabel("Resize sidebar")
    }

    private var handleColor: Color {
        isActive ? NativeProTheme.accent.opacity(0.62) : NativeProTheme.separator.opacity(0.70)
    }
}

private struct RightPanelResizeHandle: View {
    let isActive: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 12)
            .overlay {
                Capsule()
                    .fill(handleColor)
                    .frame(width: (isHovering || isActive) ? 4 : 2)
                    .opacity((isHovering || isActive) ? 1 : 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onChanged(value.translation.width)
                    }
                    .onEnded { _ in
                        onEnded()
                    }
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .accessibilityLabel("Resize right panel")
    }

    private var handleColor: Color {
        isActive ? NativeProTheme.accent.opacity(0.62) : NativeProTheme.separator.opacity(0.70)
    }
}

private struct DropTargetOverlay: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        ZStack {
            NativeProTheme.accent.opacity(0.08)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(NativeProTheme.accent)

                Text(language.text("drop.title"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NativeProTheme.accent.opacity(0.35), lineWidth: 1)
            }
        }
    }
}

private struct CommandRailView: View {
    @ObservedObject var model: ReaderModel
    let usesSidebarCollapse: Bool
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        GeometryReader { proxy in
            let metrics = CommandRailMetrics(availableHeight: proxy.size.height, slotWidth: proxy.size.width)
            let shellShadow = metrics.shellShadow(for: colorScheme)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    CommandRailLogoView(metrics: metrics)

                    VStack(spacing: metrics.itemSpacing) {
                        RailButton(
                            title: model.rightPanelMode == .chat && model.isInspectorVisible ? "Hide Chat" : "Chat",
                            systemImage: "bubble.left.and.bubble.right",
                            isActive: model.rightPanelMode == .chat && model.isInspectorVisible,
                            metrics: metrics
                        ) {
                            model.toggleChat()
                        }

                        RailButton(
                            title: language.text("library.title"),
                            systemImage: "folder",
                            isActive: model.isLibraryOverlayVisible,
                            metrics: metrics
                        ) {
                            model.showLibrary()
                        }

                        RailButton(
                            title: language.text("thumbnails.title"),
                            systemImage: "sidebar.leading",
                            isActive: model.hasDocument && model.isSidebarVisible && !model.isLibraryOverlayVisible,
                            metrics: metrics
                        ) {
                            if model.hasDocument {
                                model.toggleThumbnails()
                            } else {
                                model.showLibrary()
                            }
                        }

                        RailButton(
                            title: "Search",
                            systemImage: "magnifyingglass",
                            isActive: model.rightPanelMode == .research && model.inspectorTab == .search && model.isInspectorVisible,
                            metrics: metrics
                        ) {
                            model.showResearch(tab: .search)
                        }
                    }
                    .padding(.top, metrics.logoItemSpacing)
                }
                .padding(.top, metrics.logoTopPadding)
                .padding(.bottom, metrics.verticalPadding)
                .frame(width: metrics.containerWidth)
                .padding(.horizontal, metrics.shellPadding)
                .padding(.vertical, metrics.shellPadding)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: metrics.shellCornerRadius, style: .continuous),
                    fallbackColor: NativeProTheme.commandRailShell,
                    strokeColor: NativeProTheme.separator.opacity(0.20)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: metrics.shellCornerRadius, style: .continuous)
                        .fill(metrics.shellDepth(for: colorScheme))
                        .allowsHitTesting(false)
                }
                .shadow(color: shellShadow.color, radius: shellShadow.radius, x: shellShadow.x, y: shellShadow.y)
            }
            .padding(.top, metrics.railTopInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.clear)
        }
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

private struct CommandRailLogoView: View {
    let metrics: CommandRailMetrics

    var body: some View {
        AppLogoView(size: metrics.logoSize)
            .frame(width: metrics.hitFrame, height: metrics.hitFrame)
            .contentShape(RoundedRectangle(cornerRadius: metrics.buttonRadius, style: .continuous))
            .help("ReadArc")
            .accessibilityLabel("ReadArc")
    }
}

private struct RailSettingsMenu: View {
    @Binding var appearanceMode: AppAppearanceMode
    @Binding var appLanguage: AppLanguage
    @Environment(\.appLanguage) private var language

    var body: some View {
        Menu {
            Section(language.text("appearance")) {
                settingButton(
                    title: language.text("appearance.system"),
                    systemImage: "circle.lefthalf.filled",
                    isSelected: appearanceMode == .system
                ) {
                    appearanceMode = .system
                }
                settingButton(
                    title: language.text("appearance.light"),
                    systemImage: "sun.max",
                    isSelected: appearanceMode == .light
                ) {
                    appearanceMode = .light
                }
                settingButton(
                    title: language.text("appearance.dark"),
                    systemImage: "moon",
                    isSelected: appearanceMode == .dark
                ) {
                    appearanceMode = .dark
                }
            }

            Section(language.text("language")) {
                settingButton(
                    title: language.text("language.system"),
                    systemImage: "globe",
                    isSelected: appLanguage == .system
                ) {
                    appLanguage = .system
                }
                settingButton(
                    title: language.text("language.chinese"),
                    systemImage: "character.bubble",
                    isSelected: appLanguage == .simplifiedChinese
                ) {
                    appLanguage = .simplifiedChinese
                }
                settingButton(
                    title: language.text("language.english"),
                    systemImage: "textformat",
                    isSelected: appLanguage == .english
                ) {
                    appLanguage = .english
                }
            }

            Section(language.text("updates.title")) {
                Button {
                    AppUpdateChecker.checkForUpdates(language: language)
                } label: {
                    Label(language.text("updates.check"), systemImage: "arrow.down.circle")
                }
            }

            Section("ReadArc") {
                Button {
                    if let url = URL(string: "https://github.com/Zanetach/ReadArc") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(language.text("github.star"), systemImage: "star")
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44, height: 44)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                    fallbackColor: Color.clear,
                    strokeColor: Color.clear,
                    isInteractive: true
                )
                .foregroundStyle(NativeProTheme.muted)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 54, height: 50)
        .help(language.text("settings.title"))
        .accessibilityLabel(language.text("settings.title"))
    }

    private func settingButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: isSelected ? "checkmark" : systemImage)
        }
    }
}

private struct RightPanelModeSwitcher: View {
    let selectedMode: RightPanelMode
    let selectMode: (RightPanelMode) -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RightPanelMode.allCases) { mode in
                Button {
                    guard selectedMode != mode else { return }
                    selectMode(mode)
                } label: {
                    Text(mode.title(language: language))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedMode == mode ? NativeProTheme.accent : NativeProTheme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.14), value: selectedMode)
    }
}

private struct RailButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let metrics: CommandRailMetrics
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: metrics.iconSize, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.muted)
                .opacity(isActive ? 1 : 0.82)
                .frame(width: metrics.hitFrame, height: metrics.hitFrame)
            .contentShape(RoundedRectangle(cornerRadius: metrics.buttonRadius, style: .continuous))
        }
        .frame(width: metrics.hitFrame, height: metrics.hitFrame)
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: metrics.buttonRadius, style: .continuous))
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct CommandRailMetrics {
    let availableHeight: CGFloat
    let slotWidth: CGFloat

    static func slotWidth(for height: CGFloat, windowWidth: CGFloat) -> CGFloat {
        if height < 620 {
            return 54
        }
        if height > 900, windowWidth >= 1280 {
            return 60
        }
        return windowWidth < 980 ? 56 : 58
    }

    var buttonFrame: CGFloat {
        clamp(availableHeight * 0.055, lower: 40, upper: 46)
    }

    var hitFrame: CGFloat {
        max(44, buttonFrame + 4)
    }

    var iconSize: CGFloat {
        clamp(buttonFrame * 0.42, lower: 16, upper: 19)
    }

    var logoSize: CGFloat {
        clamp(buttonFrame * 0.84, lower: 32, upper: 39)
    }

    var verticalPadding: CGFloat {
        clamp(availableHeight * 0.024, lower: 12, upper: 22)
    }

    var logoTopPadding: CGFloat {
        clamp(availableHeight * 0.006, lower: 2, upper: 6)
    }

    var railTopInset: CGFloat {
        if availableHeight < 520 {
            return 4
        }
        return clamp(availableHeight * 0.014, lower: 8, upper: 12)
    }

    var logoItemSpacing: CGFloat {
        clamp(itemSpacing + 4, lower: 12, upper: 18)
    }

    var itemSpacing: CGFloat {
        let targetHeight = min(max(availableHeight * 0.42, minimumContentHeight), min(availableHeight - 40, 360))
        let spacing = (targetHeight - fixedContentHeight - verticalPadding * 2) / 4
        return clamp(spacing, lower: 8, upper: 14)
    }

    var containerWidth: CGFloat {
        min(max(buttonFrame + 6, 48), max(48, slotWidth - 6))
    }

    var containerCornerRadius: CGFloat {
        clamp(containerWidth * 0.42, lower: 20, upper: 26)
    }

    var buttonRadius: CGFloat {
        clamp(buttonFrame * 0.28, lower: 12, upper: 15)
    }

    var shadowRadius: CGFloat {
        clamp(buttonFrame * 0.36, lower: 14, upper: 20)
    }

    var shellPadding: CGFloat {
        clamp(slotWidth * 0.08, lower: 4, upper: 7)
    }

    var shellCornerRadius: CGFloat {
        clamp(slotWidth * 0.26, lower: 18, upper: 24)
    }

    func shellDepth(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .light {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.115),
                    Color.white.opacity(0.035),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(0.050),
                Color.clear,
                Color.black.opacity(0.100)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func shellShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        if colorScheme == .light {
            return (
                color: Color.black.opacity(0.075),
                radius: clamp(shadowRadius * 0.70, lower: 9, upper: 12),
                x: 0,
                y: 6
            )
        }

        return (
            color: Color.black.opacity(0.34),
            radius: shadowRadius + 8,
            x: 8,
            y: 18
        )
    }

    private var fixedContentHeight: CGFloat {
        hitFrame * 5
    }

    private var minimumContentHeight: CGFloat {
        fixedContentHeight + verticalPadding * 2 + 8 * 4
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

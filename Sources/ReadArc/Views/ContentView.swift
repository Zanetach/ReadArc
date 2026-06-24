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
        GeometryReader { proxy in
            let layout = ResponsiveReaderLayout(width: proxy.size.width)
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

            VStack(spacing: 0) {
                ReaderToolbar(model: model)

                HStack(spacing: 0) {
                    CommandRailView(model: model, usesSidebarCollapse: layout.showsSidebar)
                        .frame(width: layout.railWidth)

                    if leftSidebarVisible {
                        leftSidebar
                            .frame(width: leftSidebarWidth)
                            .transition(.move(edge: .leading).combined(with: .opacity))

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

                    DetailView(model: model)
                        .frame(minWidth: 0, maxWidth: .infinity)

                    if model.isInspectorVisible {
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

                        rightPanel
                            .frame(width: rightPanelWidth)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NativeProTheme.window)
        }
        .ignoresSafeArea(.container, edges: .top)
        .animation(.easeInOut(duration: 0.16), value: model.isInspectorVisible)
        .animation(.easeInOut(duration: 0.16), value: model.isSidebarVisible)
        .animation(.easeInOut(duration: 0.16), value: model.isLibraryOverlayVisible)
        .animation(.easeInOut(duration: 0.16), value: model.rightPanelMode)
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
        .tint(NativeProTheme.accent)
        .background(NativeProTheme.window)
        .alert("Unable to Open PDF", isPresented: errorBinding) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
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
                clearRecents: model.clearRecents
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
                        modeSwitcher: AnyView(RightPanelModeSwitcher(model: model))
                    )
                case .focus, .research:
                    DocumentInspectorView(
                        model: model,
                        modeSwitcher: AnyView(RightPanelModeSwitcher(model: model))
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            fallbackColor: NativeProTheme.inspector.opacity(0.96),
            strokeColor: NativeProTheme.separator.opacity(0.55)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 10)
        .padding(.bottom, 10)
        .padding(.trailing, 10)
    }

    private func openDroppedPDF(from urls: [URL]) -> Bool {
        guard let pdfURL = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
            model.errorMessage = "Drop a PDF file to open it."
            return false
        }

        model.load(url: pdfURL)
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

private struct ResponsiveReaderLayout {
    let width: CGFloat

    var railWidth: CGFloat {
        width < 980 ? 62 : 76
    }

    var showsSidebar: Bool {
        width >= 940
    }

    var defaultSidebarWidth: CGFloat {
        width < 980 ? 168 : (width < 1160 ? 176 : 202)
    }

    var minSidebarWidth: CGFloat {
        width < 980 ? 168 : 188
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
        if width < 980 {
            return 280
        }
        if width < 1400 {
            return 380
        }
        return 460
    }

    var minRightPanelWidth: CGFloat {
        width < 980 ? 260 : 340
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
        let minReaderWidth: CGFloat = width < 980 ? 300 : 420
        let available = width - railWidth - rightWidth - minReaderWidth
        return max(minSidebarWidth, min(420, available))
    }

    private func maxRightPanelWidth(leftSidebarWidth: CGFloat, sidebarVisible: Bool, libraryOverlayVisible: Bool) -> CGFloat {
        let sidebarIsShown = (showsSidebar && sidebarVisible) || libraryOverlayVisible
        let occupiedWidth = railWidth + (sidebarIsShown ? leftSidebarWidth : 0)
        let minReaderWidth: CGFloat = width < 980 ? 300 : 380
        let available = width - occupiedWidth - minReaderWidth
        return max(minRightPanelWidth, min(840, available))
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
            .frame(width: 14)
            .overlay {
                Capsule()
                    .fill((isHovering || isActive) ? NativeProTheme.accent.opacity(0.72) : NativeProTheme.separator.opacity(0.45))
                    .frame(width: (isHovering || isActive) ? 4 : 2)
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
            .help("Resize sidebar")
            .accessibilityLabel("Resize sidebar")
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
            .frame(width: 16)
            .overlay {
                Capsule()
                    .fill((isHovering || isActive) ? NativeProTheme.accent.opacity(0.78) : NativeProTheme.separator.opacity(0.9))
                    .frame(width: (isHovering || isActive) ? 4 : 2)
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
            .help("Resize panel")
            .accessibilityLabel("Resize right panel")
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
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            ReadArcGlassContainer(spacing: 8) {
                VStack(spacing: 8) {
                    RailButton(title: model.rightPanelMode == .chat && model.isInspectorVisible ? "Hide Chat" : "Chat", systemImage: "bubble.left.and.bubble.right", isActive: model.rightPanelMode == .chat && model.isInspectorVisible) {
                        model.toggleChat()
                    }

                    RailButton(
                        title: language.text("library.title"),
                        systemImage: "folder",
                        isActive: model.isLibraryOverlayVisible
                    ) {
                        model.showLibrary()
                    }

                    RailButton(
                        title: language.text("thumbnails.title"),
                        systemImage: "sidebar.leading",
                        isActive: model.hasDocument && model.isSidebarVisible && !model.isLibraryOverlayVisible
                    ) {
                        if model.hasDocument {
                            model.showThumbnails()
                        } else {
                            model.showLibrary()
                        }
                    }
                    RailButton(title: "Search", systemImage: "magnifyingglass", isActive: model.rightPanelMode == .research && model.inspectorTab == .search && model.isInspectorVisible) {
                        model.showResearch(tab: .search)
                    }
                    RailButton(title: "Notes", systemImage: "note.text", isActive: model.rightPanelMode == .focus && model.isInspectorVisible) {
                        model.showFocus()
                    }
                    RailButton(title: "Outline", systemImage: "list.bullet.rectangle", isActive: model.rightPanelMode == .research && model.inspectorTab == .outline && model.isInspectorVisible) {
                        model.showResearch(tab: .outline)
                    }
                }
                .padding(.vertical, 6)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous),
                    fallbackColor: NativeProTheme.panel.opacity(0.26),
                    strokeColor: NativeProTheme.separator.opacity(0.45)
                )
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            RailSettingsMenu(
                appearanceMode: appearanceMode,
                appLanguage: appLanguage
            )
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.clear)
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
    @ObservedObject var model: ReaderModel
    @Environment(\.appLanguage) private var language

    var body: some View {
        Picker("Right Panel", selection: panelMode) {
            ForEach(RightPanelMode.allCases) { mode in
                Label(mode.title(language: language), systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
    }

    private var panelMode: Binding<RightPanelMode> {
        Binding(
            get: { model.rightPanelMode },
            set: { model.showRightPanel($0) }
        )
    }
}

private struct RailButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44, height: 44)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                    fallbackColor: isActive ? NativeProTheme.selection : Color.clear,
                    strokeColor: isActive ? NativeProTheme.accent.opacity(0.40) : .clear,
                    isInteractive: true,
                    tint: isActive ? NativeProTheme.accent.opacity(0.18) : nil
                )
                .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.muted)
        }
        .frame(width: 54, height: 50)
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ReaderModel
    @State private var isDropTargeted = false
    @State private var rightPanelDragStartWidth: CGFloat?
    @SceneStorage("readArcRightPanelWidth") private var preferredRightPanelWidth: Double = 0
    @Environment(\.appLanguage) private var language

    var body: some View {
        GeometryReader { proxy in
            let layout = ResponsiveReaderLayout(width: proxy.size.width)
            let rightPanelWidth = layout.rightPanelWidth(
                preferredWidth: preferredRightPanelWidth,
                sidebarVisible: model.isSidebarVisible,
                libraryOverlayVisible: model.isLibraryOverlayVisible
            )

            VStack(spacing: 0) {
                ReaderToolbar(model: model)

                HStack(spacing: 0) {
                    CommandRailView(model: model, usesSidebarCollapse: layout.showsSidebar)
                        .frame(width: layout.railWidth)

                    if (layout.showsSidebar && model.isSidebarVisible) || model.isLibraryOverlayVisible {
                        leftSidebar
                        .frame(width: layout.sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
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
        .background(NativeProTheme.inspector.opacity(0.98))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(width: 1)
        }
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
            sidebarVisible: model.isSidebarVisible,
            libraryOverlayVisible: model.isLibraryOverlayVisible
        )
        preferredRightPanelWidth = Double(clampedWidth)
    }
}

private struct ResponsiveReaderLayout {
    let width: CGFloat

    var railWidth: CGFloat {
        width < 980 ? 58 : 82
    }

    var showsSidebar: Bool {
        width >= 940
    }

    var sidebarWidth: CGFloat {
        width < 980 ? 168 : (width < 1160 ? 176 : 202)
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
        sidebarVisible: Bool,
        libraryOverlayVisible: Bool
    ) -> CGFloat {
        let preferred = preferredWidth > 0 ? CGFloat(preferredWidth) : defaultRightPanelWidth
        return clampedRightPanelWidth(
            preferred,
            sidebarVisible: sidebarVisible,
            libraryOverlayVisible: libraryOverlayVisible
        )
    }

    func clampedRightPanelWidth(
        _ proposedWidth: CGFloat,
        sidebarVisible: Bool = false,
        libraryOverlayVisible: Bool = false
    ) -> CGFloat {
        min(max(proposedWidth, minRightPanelWidth), maxRightPanelWidth(sidebarVisible: sidebarVisible, libraryOverlayVisible: libraryOverlayVisible))
    }

    private func maxRightPanelWidth(sidebarVisible: Bool, libraryOverlayVisible: Bool) -> CGFloat {
        let sidebarIsShown = (showsSidebar && sidebarVisible) || libraryOverlayVisible
        let occupiedWidth = railWidth + (sidebarIsShown ? sidebarWidth : 0)
        let minReaderWidth: CGFloat = width < 980 ? 300 : 380
        let available = width - occupiedWidth - minReaderWidth
        return max(minRightPanelWidth, min(840, available))
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
            VStack(spacing: 10) {
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
            .padding(.top, 28)
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            RailSettingsMenu(
                appearanceMode: appearanceMode,
                appLanguage: appLanguage
            )
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(NativeProTheme.commandRail)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(width: 1)
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
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44, height: 44)
                .background(Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .background(isActive ? NativeProTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isActive ? NativeProTheme.accent.opacity(0.40) : .clear, lineWidth: 1)
                }
                .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.muted)
        }
        .frame(width: 54, height: 50)
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

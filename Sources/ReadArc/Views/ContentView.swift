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

            HStack(spacing: 0) {
                CommandRailView(model: model, usesSidebarCollapse: layout.showsSidebar)
                    .frame(width: layout.railWidth)

                if (layout.showsSidebar && model.isSidebarVisible) || model.isLibraryOverlayVisible {
                    SidebarView(
                        recents: model.recents,
                        selectedURL: model.documentURL,
                        readerMode: model.readerMode,
                        openDocument: model.openDocument,
                        openRecent: model.openRecent,
                        removeRecent: model.removeRecent,
                        clearRecents: model.clearRecents
                    )
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
    private var rightPanel: some View {
        switch model.rightPanelMode {
        case .inspector:
            DocumentInspectorView(model: model)
        case .chat:
            AgentChatView(model: model)
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
        width < 980 ? 56 : 64
    }

    var showsSidebar: Bool {
        width >= 940
    }

    var sidebarWidth: CGFloat {
        width < 980 ? 252 : (width < 1160 ? 224 : 252)
    }

    var defaultRightPanelWidth: CGFloat {
        if width < 980 {
            return 280
        }
        if width < 1400 {
            return 318
        }
        return 344
    }

    var minRightPanelWidth: CGFloat {
        width < 980 ? 260 : 300
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
        let minReaderWidth: CGFloat = width < 980 ? 360 : 460
        let available = width - occupiedWidth - minReaderWidth
        return max(minRightPanelWidth, min(640, available))
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
            .frame(width: 8)
            .overlay {
                Capsule()
                    .fill((isHovering || isActive) ? NativeProTheme.accent.opacity(0.65) : NativeProTheme.separator)
                    .frame(width: (isHovering || isActive) ? 3 : 1)
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
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            AppLogoView(size: 42)
                .frame(width: 48, height: 48)
                .padding(.top, 15)

            VStack(spacing: 10) {
                RailButton(
                    title: usesSidebarCollapse && model.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                    systemImage: "sidebar.leading",
                    isActive: usesSidebarCollapse && model.isSidebarVisible
                ) {
                    if usesSidebarCollapse {
                        model.toggleSidebar()
                    } else {
                        model.showLibrary()
                    }
                }

                RailButton(title: "Library", systemImage: "book.pages", isActive: model.isLibraryOverlayVisible) {
                    if usesSidebarCollapse {
                        model.showSidebar()
                    } else {
                        model.showLibrary()
                    }
                }
                RailButton(title: "Search", systemImage: "magnifyingglass", isActive: model.rightPanelMode == .inspector && model.inspectorTab == .search && model.readerMode == .research && model.isInspectorVisible) {
                    model.readerMode = .research
                    model.showInspector(tab: .search)
                }
                RailButton(title: "Notes", systemImage: "note.text", isActive: model.rightPanelMode == .inspector && model.inspectorTab == .notes && model.isInspectorVisible) {
                    model.showInspector(tab: .notes)
                }
                RailButton(title: "Outline", systemImage: "list.bullet.rectangle", isActive: model.rightPanelMode == .inspector && model.inspectorTab == .outline && model.isInspectorVisible) {
                    model.showInspector(tab: .outline)
                }
            }
            .padding(.top, 26)
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            RailButton(title: model.rightPanelMode == .chat && model.isInspectorVisible ? "Hide Chat" : "Chat", systemImage: "bubble.left.and.bubble.right", isActive: model.rightPanelMode == .chat && model.isInspectorVisible) {
                model.toggleChat()
            }
            .padding(.bottom, 12)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NativeProTheme.success)
                .frame(width: 30, height: 30)
                .background(NativeProTheme.successSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.bottom, 16)
                .help("Indexed")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(NativeProTheme.commandRail)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(width: 1)
        }
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
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 40, height: 40)
                .background(isActive ? NativeProTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.muted)
        }
        .frame(width: 48, height: 44)
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

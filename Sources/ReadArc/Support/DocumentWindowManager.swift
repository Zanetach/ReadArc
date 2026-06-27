import AppKit
import ReadArcCore
import SwiftUI

@MainActor
final class DocumentWindowManager {
    static let shared = DocumentWindowManager()

    private var entries: [UUID: WindowEntry] = [:]
    private var windowsByDocumentKey: [String: WeakWindow] = [:]
    private var documentKeysByWindowID: [ObjectIdentifier: String] = [:]

    private init() {}

    func openDocumentWindows(_ urls: [URL]) {
        PDFOpenPlanner.uniqueDocumentWindowURLs(from: urls).forEach(openDocumentWindow)
    }

    func openDocumentWindow(_ url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else { return }

        let standardizedURL = PDFOpenPlanner.standardizedDocumentURL(url)
        let documentKey = PDFOpenPlanner.documentWindowKey(for: standardizedURL)
        if let existingWindow = visibleWindow(for: documentKey) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let id = UUID()
        let title = standardizedURL.deletingPathExtension().lastPathComponent
        let hostingController = NSHostingController(rootView: ManagedDocumentWindowView(initialDocumentURL: standardizedURL))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 680, height: 420)
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        place(window)

        let controller = NSWindowController(window: window)
        let delegate = DocumentWindowDelegate { [weak self] in
            self?.entries[id] = nil
            self?.unregisterDocumentWindow(window)
        }
        window.delegate = delegate
        entries[id] = WindowEntry(controller: controller, delegate: delegate)
        registerDocumentWindow(standardizedURL, window: window)

        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func registerDocumentWindow(_ url: URL, window: NSWindow) {
        let windowID = ObjectIdentifier(window)
        if let previousKey = documentKeysByWindowID[windowID] {
            windowsByDocumentKey[previousKey] = nil
        }

        let documentKey = PDFOpenPlanner.documentWindowKey(for: url)
        windowsByDocumentKey[documentKey] = WeakWindow(window)
        documentKeysByWindowID[windowID] = documentKey
    }

    private func unregisterDocumentWindow(_ window: NSWindow) {
        let windowID = ObjectIdentifier(window)
        guard let documentKey = documentKeysByWindowID.removeValue(forKey: windowID) else { return }
        if windowsByDocumentKey[documentKey]?.window === window {
            windowsByDocumentKey[documentKey] = nil
        }
    }

    private func visibleWindow(for documentKey: String) -> NSWindow? {
        guard let window = windowsByDocumentKey[documentKey]?.window else {
            windowsByDocumentKey[documentKey] = nil
            return nil
        }

        guard window.isVisible else {
            unregisterDocumentWindow(window)
            return nil
        }

        return window
    }

    private func place(_ window: NSWindow) {
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            window.center()
            return
        }

        var frame = window.frame
        let offset = CGFloat(entries.count % 8) * 28
        frame.origin.x = visibleFrame.midX - frame.width / 2 + offset
        frame.origin.y = visibleFrame.midY - frame.height / 2 - offset
        frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        window.setFrame(frame, display: false)
    }
}

private struct WindowEntry {
    let controller: NSWindowController
    let delegate: DocumentWindowDelegate
}

private final class WeakWindow {
    weak var window: NSWindow?

    init(_ window: NSWindow) {
        self.window = window
    }
}

private final class DocumentWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

private struct ManagedDocumentWindowView: View {
    let initialDocumentURL: URL

    @StateObject private var model = ReaderModel()
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue
    @State private var systemColorScheme: ColorScheme = .light
    @State private var openedInitialDocumentURL: URL?

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    private var resolvedColorScheme: ColorScheme {
        appearanceMode == .system ? systemColorScheme : AppAppearanceController.resolvedColorScheme(for: appearanceMode)
    }

    var body: some View {
        ContentView(model: model)
            .frame(minWidth: 680, minHeight: 420)
            .background(WindowConfigurator(keepsSingleMainWindow: false, documentURL: model.documentURL))
            .environment(\.appLanguage, language)
            .preferredColorScheme(resolvedColorScheme)
            .focusedObject(model)
            .navigationTitle(model.documentTitle)
            .onAppear {
                configureDocumentWindowOpener()
                AppAppearanceController.apply(appearanceMode)
                refreshSystemColorScheme()
                AppAppearanceController.requestSystemAppearanceRefresh()
                openInitialDocumentIfNeeded()
            }
            .onChange(of: appearanceModeRaw) { _, _ in
                AppAppearanceController.apply(appearanceMode)
                refreshSystemColorScheme()
            }
            .onReceive(NotificationCenter.default.publisher(for: .readArcSystemAppearanceChanged)) { _ in
                AppAppearanceController.apply(appearanceMode)
                refreshSystemColorScheme()
            }
            .onOpenURL { url in
                model.openDocumentsInWindows([url])
            }
    }

    private func configureDocumentWindowOpener() {
        model.setDocumentWindowOpener { url in
            DocumentWindowManager.shared.openDocumentWindow(url)
        }
    }

    private func openInitialDocumentIfNeeded() {
        guard openedInitialDocumentURL != initialDocumentURL else { return }

        openedInitialDocumentURL = initialDocumentURL
        model.openExternalFile(initialDocumentURL)
    }

    private func refreshSystemColorScheme() {
        systemColorScheme = AppAppearanceController.currentSystemColorScheme
    }
}

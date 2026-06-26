import AppKit
import SwiftUI

@main
struct ReadArcApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = ReaderModel()
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage("appLanguage") private var languageRaw = AppLanguage.system.rawValue
    @State private var systemColorScheme: ColorScheme = .light

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    private var resolvedColorScheme: ColorScheme {
        appearanceMode == .system ? systemColorScheme : AppAppearanceController.resolvedColorScheme(for: appearanceMode)
    }

    var body: some Scene {
        WindowGroup("ReadArc") {
            ContentView(model: model)
                .frame(minWidth: 680, minHeight: 420)
                .background(WindowConfigurator())
                .environment(\.appLanguage, language)
                .preferredColorScheme(resolvedColorScheme)
                .onAppear {
                    AppAppearanceController.apply(appearanceMode)
                    refreshSystemColorScheme()
                    AppAppearanceController.requestSystemAppearanceRefresh()
                    LaunchSetupCoordinator.runIfNeeded()
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
                    model.openExternalFile(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 760)
        .commands {
            ReadArcCommands(model: model, language: language)
        }

        Settings {
            PreferencesView()
                .environment(\.appLanguage, language)
                .preferredColorScheme(resolvedColorScheme)
                .onAppear {
                    AppAppearanceController.apply(appearanceMode)
                    refreshSystemColorScheme()
                    AppAppearanceController.requestSystemAppearanceRefresh()
                }
                .onChange(of: appearanceModeRaw) { _, _ in
                    AppAppearanceController.apply(appearanceMode)
                    refreshSystemColorScheme()
                }
                .onReceive(NotificationCenter.default.publisher(for: .readArcSystemAppearanceChanged)) { _ in
                    AppAppearanceController.apply(appearanceMode)
                    refreshSystemColorScheme()
                }
        }
    }

    private func refreshSystemColorScheme() {
        systemColorScheme = AppAppearanceController.currentSystemColorScheme
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            let modeRaw = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppAppearanceMode.system.rawValue
            let mode = AppAppearanceMode(rawValue: modeRaw) ?? .system
            if mode == .system {
                AppAppearanceController.requestSystemAppearanceRefresh()
            }
        }
    }

    func application(_ application: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        false
    }

    deinit {
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        ExternalOpenRequestCenter.shared.enqueue([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        ExternalOpenRequestCenter.shared.enqueue(filenames.map(URL.init(fileURLWithPath:)))
        sender.reply(toOpenOrPrint: .success)
    }
}

struct ReadArcCommands: Commands {
    @ObservedObject var model: ReaderModel
    let language: AppLanguage

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About ReadArc") {
                AboutPanel.show()
            }

            Button(language.text("updates.check")) {
                AppUpdateChecker.checkForUpdates(language: language)
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("Open PDF...") {
                model.openDocument()
            }
            .keyboardShortcut("o")

            Button("Reveal in Finder") {
                model.revealDocumentInFinder()
            }
            .disabled(!model.hasDocument)

            Divider()

            Button("Close PDF") {
                model.closeDocument()
            }
            .keyboardShortcut("w")
            .disabled(!model.hasDocument)
        }

        CommandMenu("PDF") {
            Button(language.text("toolbar.firstPage")) {
                model.send(.firstPage)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command])
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.previousPage")) {
                model.send(.previousPage)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.nextPage")) {
                model.send(.nextPage)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.lastPage")) {
                model.send(.lastPage)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command])
            .disabled(!model.hasDocument)

            Divider()

            Button(language.text("toolbar.zoomIn")) {
                model.send(.zoomIn)
            }
            .keyboardShortcut("+")
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.zoomOut")) {
                model.send(.zoomOut)
            }
            .keyboardShortcut("-")
            .disabled(!model.hasDocument)

            Button(language.text("toolbar.actualSize")) {
                model.send(.actualSize)
            }
            .keyboardShortcut("0")
            .disabled(!model.hasDocument)

            Divider()

            Button(language.text(model.isInspectorVisible ? "toolbar.hidePanel" : "toolbar.showPanel")) {
                model.toggleInspectorPanel()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Button(language.text("toolbar.showChat")) {
                model.showChat()
            }
            .keyboardShortcut("j", modifiers: [.command, .option])
        }
    }
}

private enum AboutPanel {
    @MainActor private static var windowController: NSWindowController?

    @MainActor
    static func show() {
        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: AboutReadArcView(repositoryURL: repositoryURL))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 286),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "About ReadArc"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static var repositoryURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = ["", "Zanetach", "ReadArc.git"].joined(separator: "/")
        return components.url
    }
}

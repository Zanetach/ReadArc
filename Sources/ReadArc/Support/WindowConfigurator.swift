import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    @MainActor
    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = true
        window.backgroundColor = NSColor(
            calibratedRed: CGFloat(0xF6) / 255,
            green: CGFloat(0xF6) / 255,
            blue: CGFloat(0xF7) / 255,
            alpha: 1
        )
        window.isMovableByWindowBackground = false
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 680, height: 420)
        window.toolbar = nil

        if ReferencePreviewMode.isEnabled {
            ReferenceWindowSizer.applyIfNeeded(to: window)
        }
    }
}

@MainActor
private enum ReferenceWindowSizer {
    private static var configuredWindowIDs = Set<ObjectIdentifier>()

    static func applyIfNeeded(to window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard !configuredWindowIDs.contains(id) else { return }
        configuredWindowIDs.insert(id)

        let targetSize = NSSize(width: 2048, height: 1152)
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let width = min(targetSize.width, max(1280, visibleFrame.width - 48))
        let height = min(targetSize.height, max(760, visibleFrame.height - 72))
        let origin = NSPoint(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2
        )

        window.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }
}

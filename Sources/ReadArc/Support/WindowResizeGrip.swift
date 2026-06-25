import AppKit
import SwiftUI

struct WindowDoubleClickZoomRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDoubleClickZoomNSView {
        WindowDoubleClickZoomNSView()
    }

    func updateNSView(_ nsView: WindowDoubleClickZoomNSView, context: Context) {}
}

final class WindowDoubleClickZoomNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard
            event.clickCount == 2,
            event.modifierFlags.intersection([.control, .command, .option]).isEmpty
        else {
            super.mouseDown(with: event)
            return
        }

        window?.performZoom(nil)
    }
}

struct WindowResizeGrip: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WindowResizeGripRepresentable()
                .frame(width: 34, height: 34)

            ResizeGripMark()
                .stroke(
                    NativeProTheme.faint.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: 16, height: 16)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
                .allowsHitTesting(false)
        }
        .frame(width: 34, height: 34)
        .contentShape(Rectangle())
    }
}

private struct ResizeGripMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing = rect.width / 4

        for index in 1...3 {
            let offset = CGFloat(index) * spacing
            path.move(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - offset))
        }

        return path
    }
}

private struct WindowResizeGripRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowResizeGripNSView {
        WindowResizeGripNSView()
    }

    func updateNSView(_ nsView: WindowResizeGripNSView, context: Context) {}
}

private final class WindowResizeGripNSView: NSView {
    private var dragStartFrame: NSRect?
    private var dragStartLocation: NSPoint?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        window.makeKey()
        dragStartFrame = window.frame
        dragStartLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            let window,
            let dragStartFrame,
            let dragStartLocation
        else {
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - dragStartLocation.x
        let deltaY = currentLocation.y - dragStartLocation.y
        let minSize = window.minSize

        let newWidth = max(minSize.width, dragStartFrame.width + deltaX)
        let newHeight = max(minSize.height, dragStartFrame.height - deltaY)
        let newOriginY = dragStartFrame.maxY - newHeight
        let newFrame = NSRect(
            x: dragStartFrame.minX,
            y: newOriginY,
            width: newWidth,
            height: newHeight
        )

        window.setFrame(newFrame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartFrame = nil
        dragStartLocation = nil
    }
}

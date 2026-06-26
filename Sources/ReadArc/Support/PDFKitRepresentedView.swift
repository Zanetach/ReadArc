import PDFKit
import SwiftUI

struct PDFKitRepresentedView: NSViewRepresentable {
    @ObservedObject var model: ReaderModel
    let interactionTool: ReaderCanvasTool

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> DoubleClickPDFView {
        let pdfView = DoubleClickPDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 6.0
        pdfView.backgroundColor = NativeProTheme.readerCanvasNSColor
        pdfView.interactionTool = interactionTool
        context.coordinator.attach(to: pdfView)
        pdfView.doubleClickHandler = { [weak coordinator = context.coordinator] pdfView, event in
            coordinator?.toggleZoom(onDoubleClick: event, in: pdfView)
        }
        pdfView.layoutHandler = { [weak coordinator = context.coordinator] pdfView in
            coordinator?.handleLayout(in: pdfView)
        }
        return pdfView
    }

    func updateNSView(_ pdfView: DoubleClickPDFView, context: Context) {
        context.coordinator.model = model
        if pdfView.displayMode != .singlePageContinuous {
            pdfView.displayMode = .singlePageContinuous
        }
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.interactionTool = interactionTool

        if pdfView.document !== model.document {
            pdfView.document = model.document
            context.coordinator.scheduleFitPageWidth(in: pdfView)
            context.coordinator.scheduleSync(from: pdfView)
        }

        if let command = model.pendingCommand {
            context.coordinator.perform(command, in: pdfView)
            DispatchQueue.main.async {
                if model.pendingCommand?.id == command.id {
                    model.pendingCommand = nil
                }
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var model: ReaderModel

        private weak var pdfView: PDFView?

        init(model: ReaderModel) {
            self.model = model
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to pdfView: PDFView) {
            self.pdfView = pdfView

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePDFViewChange(_:)),
                name: .PDFViewPageChanged,
                object: pdfView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handlePDFViewChange(_:)),
                name: .PDFViewScaleChanged,
                object: pdfView
            )

            scheduleSync(from: pdfView)
        }

        func perform(_ command: PDFViewCommand, in pdfView: PDFView) {
            switch command.action {
            case .previousPage:
                clearSearchHighlight(in: pdfView)
                pdfView.goToPreviousPage(nil)
            case .nextPage:
                clearSearchHighlight(in: pdfView)
                pdfView.goToNextPage(nil)
            case .firstPage:
                clearSearchHighlight(in: pdfView)
                pdfView.goToFirstPage(nil)
            case .lastPage:
                clearSearchHighlight(in: pdfView)
                pdfView.goToLastPage(nil)
            case .goToPage(let pageIndex):
                clearSearchHighlight(in: pdfView)
                if let page = pdfView.document?.page(at: pageIndex) {
                    pdfView.go(to: page)
                }
            case .goToSearchMatch(let pageIndex, let location, let length):
                goToSearchMatch(pageIndex: pageIndex, location: location, length: length, in: pdfView)
            case .zoomIn:
                isWidthFitted = false
                pdfView.autoScales = false
                pdfView.scaleFactor = min(pdfView.scaleFactor * 1.2, 6.0)
            case .zoomOut:
                isWidthFitted = false
                pdfView.autoScales = false
                pdfView.scaleFactor = max(pdfView.scaleFactor / 1.2, 0.25)
            case .actualSize:
                isWidthFitted = false
                pdfView.autoScales = false
                pdfView.scaleFactor = 1
            case .fitToView:
                isWidthFitted = true
                scheduleFitPageWidth(in: pdfView)
            }

            scheduleSync(from: pdfView)
        }

        func scheduleFitPageWidth(in pdfView: PDFView) {
            guard !isFitScheduled else { return }
            isFitScheduled = true
            DispatchQueue.main.async { [weak self, weak pdfView] in
                guard let self, let pdfView else { return }
                self.isFitScheduled = false
                self.fitPageWidth(in: pdfView)
            }
        }

        func fitPageWidth(in pdfView: PDFView) {
            guard let page = pdfView.currentPage ?? pdfView.document?.page(at: 0) else {
                pdfView.autoScales = true
                return
            }

            pdfView.autoScales = false
            let pageBounds = page.bounds(for: pdfView.displayBox)
            guard pageBounds.width > 0 else {
                pdfView.autoScales = true
                return
            }

            let viewportWidth = pdfView.enclosingScrollView?.contentView.bounds.width ?? pdfView.bounds.width
            guard viewportWidth > 80 else {
                scheduleFitPageWidth(in: pdfView)
                return
            }

            let horizontalInset: CGFloat = 28
            let targetWidth = max(1, viewportWidth - horizontalInset)
            let scale = targetWidth / pageBounds.width
            pdfView.scaleFactor = min(max(scale, pdfView.minScaleFactor), pdfView.maxScaleFactor)
            scheduleSync(from: pdfView)
        }

        func handleLayout(in pdfView: PDFView) {
            guard isWidthFitted, pdfView.document != nil else { return }
            scheduleFitPageWidth(in: pdfView)
        }

        private func goToSearchMatch(pageIndex: Int, location: Int, length: Int, in pdfView: PDFView) {
            guard let page = pdfView.document?.page(at: pageIndex) else { return }
            let range = NSRange(location: location, length: length)

            guard let selection = page.selection(for: range) else {
                pdfView.go(to: page)
                return
            }

            pdfView.highlightedSelections = [selection]
            pdfView.setCurrentSelection(selection, animate: true)
            pdfView.go(to: selection)
        }

        private func clearSearchHighlight(in pdfView: PDFView) {
            pdfView.highlightedSelections = []
            pdfView.clearSelection()
        }

        func toggleZoom(onDoubleClick event: NSEvent, in pdfView: PDFView) {
            let viewPoint = pdfView.convert(event.locationInWindow, from: nil)
            let page = pdfView.page(for: viewPoint, nearest: true)
            let pagePoint = page.map { pdfView.convert(viewPoint, to: $0) }
            let fittedScale = page.map { page -> CGFloat in
                let pageBounds = page.bounds(for: pdfView.displayBox)
                guard pageBounds.width > 0 else { return max(pdfView.scaleFactorForSizeToFit, pdfView.minScaleFactor) }
                let viewportWidth = pdfView.enclosingScrollView?.contentView.bounds.width ?? pdfView.bounds.width
                return min(max((viewportWidth - 28) / pageBounds.width, pdfView.minScaleFactor), pdfView.maxScaleFactor)
            } ?? max(pdfView.scaleFactorForSizeToFit, pdfView.minScaleFactor)
            let isFitted = abs(pdfView.scaleFactor - fittedScale) < 0.04

            if isFitted {
                isWidthFitted = false
                pdfView.autoScales = false
                pdfView.scaleFactor = min(max(fittedScale * 2.0, 1.5), pdfView.maxScaleFactor)
            } else {
                isWidthFitted = true
                scheduleFitPageWidth(in: pdfView)
            }

            if let page, let pagePoint {
                pdfView.go(to: PDFDestination(page: page, at: pagePoint))
            }
            scheduleSync(from: pdfView)
        }

        func scheduleSync(from pdfView: PDFView) {
            let pageCount = pdfView.document?.pageCount ?? 0
            let currentPageIndex: Int

            if let document = pdfView.document, let currentPage = pdfView.currentPage {
                currentPageIndex = document.index(for: currentPage)
            } else {
                currentPageIndex = 0
            }

            let snapshot = PDFViewSyncSnapshot(
                pageIndex: currentPageIndex,
                pageCount: pageCount,
                scaleFactor: pdfView.scaleFactor
            )

            pendingSyncSnapshot = snapshot
            guard !isSyncScheduled else { return }

            isSyncScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self, let snapshot = self.pendingSyncSnapshot else { return }
                self.pendingSyncSnapshot = nil
                self.isSyncScheduled = false

                guard snapshot != self.lastAppliedSyncSnapshot else { return }
                self.lastAppliedSyncSnapshot = snapshot
                self.model.syncFromPDFView(
                    pageIndex: snapshot.pageIndex,
                    pageCount: snapshot.pageCount,
                    scaleFactor: snapshot.scaleFactor
                )
            }
        }

        @objc private func handlePDFViewChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            scheduleSync(from: pdfView)
        }

        private var isSyncScheduled = false
        private var isFitScheduled = false
        private var isWidthFitted = true
        private var pendingSyncSnapshot: PDFViewSyncSnapshot?
        private var lastAppliedSyncSnapshot: PDFViewSyncSnapshot?
    }
}

private struct PDFViewSyncSnapshot: Equatable {
    let pageIndex: Int
    let pageCount: Int
    let scaleFactor: CGFloat

    static func == (lhs: PDFViewSyncSnapshot, rhs: PDFViewSyncSnapshot) -> Bool {
        lhs.pageIndex == rhs.pageIndex
            && lhs.pageCount == rhs.pageCount
            && abs(lhs.scaleFactor - rhs.scaleFactor) <= 0.005
    }
}

final class DoubleClickPDFView: PDFView {
    var doubleClickHandler: ((DoubleClickPDFView, NSEvent) -> Void)?
    var layoutHandler: ((DoubleClickPDFView) -> Void)?
    var interactionTool: ReaderCanvasTool = .selectText {
        didSet {
            if interactionTool != oldValue {
                resetCursorRects()
                if interactionTool == .selectText {
                    panStartWindowLocation = nil
                    panStartClipOrigin = nil
                    popPanCursorIfNeeded()
                }
            }
        }
    }

    private var panStartWindowLocation: NSPoint?
    private var panStartClipOrigin: NSPoint?
    private var didPushPanCursor = false

    override func layout() {
        super.layout()
        layoutHandler?(self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if interactionTool == .panPage {
            addCursorRect(bounds, cursor: .openHand)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            doubleClickHandler?(self, event)
            return
        }

        if interactionTool == .panPage {
            panStartWindowLocation = event.locationInWindow
            panStartClipOrigin = activeScrollView?.contentView.bounds.origin
            pushPanCursorIfNeeded()
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard interactionTool == .panPage,
              let scrollView = activeScrollView,
              let startWindowLocation = panStartWindowLocation,
              let startClipOrigin = panStartClipOrigin else {
            super.mouseDragged(with: event)
            return
        }

        let deltaX = event.locationInWindow.x - startWindowLocation.x
        let deltaY = event.locationInWindow.y - startWindowLocation.y
        let proposedOrigin = NSPoint(
            x: startClipOrigin.x - deltaX,
            y: startClipOrigin.y + deltaY
        )
        scroll(to: constrainedScrollOrigin(proposedOrigin, in: scrollView), in: scrollView)
    }

    override func mouseUp(with event: NSEvent) {
        if interactionTool == .panPage {
            panStartWindowLocation = nil
            panStartClipOrigin = nil
            popPanCursorIfNeeded()
            return
        }

        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
    }

    private func scroll(to origin: NSPoint, in scrollView: NSScrollView) {
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func pushPanCursorIfNeeded() {
        guard !didPushPanCursor else { return }
        NSCursor.closedHand.push()
        didPushPanCursor = true
    }

    private func popPanCursorIfNeeded() {
        guard didPushPanCursor else { return }
        NSCursor.pop()
        didPushPanCursor = false
    }

    private var activeScrollView: NSScrollView? {
        enclosingScrollView ?? firstDescendant(of: NSScrollView.self, in: self)
    }

    private func firstDescendant<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        for subview in view.subviews {
            if let match = subview as? T {
                return match
            }
            if let match: T = firstDescendant(of: type, in: subview) {
                return match
            }
        }
        return nil
    }

    private func constrainedScrollOrigin(_ origin: NSPoint, in scrollView: NSScrollView) -> NSPoint {
        guard let documentView = scrollView.documentView else {
            return origin
        }

        let viewportSize = scrollView.contentView.bounds.size
        let documentBounds = documentView.bounds
        let minX = documentBounds.minX
        let minY = documentBounds.minY
        let maxX = max(minX, documentBounds.maxX - viewportSize.width)
        let maxY = max(minY, documentBounds.maxY - viewportSize.height)

        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }
}

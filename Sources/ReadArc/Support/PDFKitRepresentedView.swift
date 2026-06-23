import PDFKit
import SwiftUI

struct PDFKitRepresentedView: NSViewRepresentable {
    @ObservedObject var model: ReaderModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.autoScales = true
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 6.0
        pdfView.backgroundColor = NativeProTheme.readerCanvasNSColor
        context.coordinator.attach(to: pdfView)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.model = model

        if pdfView.document !== model.document {
            pdfView.document = model.document
            pdfView.autoScales = true
            context.coordinator.sync(from: pdfView)
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

            sync(from: pdfView)
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
                pdfView.autoScales = false
                pdfView.scaleFactor = min(pdfView.scaleFactor * 1.2, 6.0)
            case .zoomOut:
                pdfView.autoScales = false
                pdfView.scaleFactor = max(pdfView.scaleFactor / 1.2, 0.25)
            case .actualSize:
                pdfView.autoScales = false
                pdfView.scaleFactor = 1
            case .fitToView:
                pdfView.autoScales = true
            }

            sync(from: pdfView)
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

        func sync(from pdfView: PDFView) {
            let pageCount = pdfView.document?.pageCount ?? 0
            let currentPageIndex: Int

            if let document = pdfView.document, let currentPage = pdfView.currentPage {
                currentPageIndex = document.index(for: currentPage)
            } else {
                currentPageIndex = 0
            }

            model.syncFromPDFView(
                pageIndex: currentPageIndex,
                pageCount: pageCount,
                scaleFactor: pdfView.scaleFactor
            )
        }

        @objc private func handlePDFViewChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            sync(from: pdfView)
        }
    }
}

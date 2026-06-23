import Foundation

struct PDFViewCommand: Equatable, Identifiable {
    let id = UUID()
    let action: PDFViewAction
}

enum PDFViewAction: Equatable {
    case previousPage
    case nextPage
    case firstPage
    case lastPage
    case goToPage(Int)
    case goToSearchMatch(pageIndex: Int, location: Int, length: Int)
    case zoomIn
    case zoomOut
    case actualSize
    case fitToView
}

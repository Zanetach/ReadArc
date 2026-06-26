enum ReaderCanvasTool {
    case selectText
    case panPage

    var titleKey: String {
        switch self {
        case .selectText:
            return "toolbar.selectText"
        case .panPage:
            return "toolbar.panPage"
        }
    }
}

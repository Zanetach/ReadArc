import AppKit
import SwiftUI

enum NativeProTheme {
    static let window = adaptive(light: rgb(0.965, 0.969, 0.976), dark: rgb(0.010, 0.013, 0.017))
    static let commandRail = adaptive(light: rgba(1.000, 1.000, 1.000, 0.520), dark: rgba(0.065, 0.071, 0.079, 0.660))
    static let sidebar = adaptive(light: rgba(1.000, 1.000, 1.000, 0.560), dark: rgba(0.078, 0.086, 0.096, 0.720))
    static let readerCanvas = adaptive(light: rgb(0.956, 0.962, 0.970), dark: rgb(0.014, 0.017, 0.022))
    static let header = adaptive(light: rgba(0.988, 0.990, 0.994, 0.740), dark: rgba(0.095, 0.104, 0.116, 0.760))
    static let inspector = adaptive(light: rgba(0.988, 0.990, 0.994, 0.620), dark: rgba(0.072, 0.080, 0.091, 0.760))
    static let inspectorResearch = adaptive(light: rgba(0.980, 0.992, 0.986, 0.640), dark: rgba(0.060, 0.079, 0.071, 0.760))
    static let panel = adaptive(light: rgba(1.000, 1.000, 1.000, 0.600), dark: rgba(0.148, 0.160, 0.178, 0.700))
    static let tile = adaptive(light: rgba(1.000, 1.000, 1.000, 0.420), dark: rgba(0.196, 0.210, 0.230, 0.620))
    static let accent = adaptive(light: rgb(0.096, 0.557, 0.370), dark: rgb(0.612, 0.920, 0.420))
    static let primaryButton = adaptive(light: rgb(0.000, 0.478, 1.000), dark: rgb(0.914, 0.922, 0.933))
    static let primaryButtonText = adaptive(light: rgb(1.000, 1.000, 1.000), dark: rgb(0.020, 0.021, 0.022))
    static let selection = adaptive(light: rgb(0.875, 0.948, 0.902), dark: rgb(0.082, 0.153, 0.096))
    static let searchHit = adaptive(light: rgb(1.000, 0.973, 0.843), dark: rgb(0.245, 0.176, 0.056))
    static let searchBorder = adaptive(light: rgb(0.929, 0.694, 0.180), dark: rgb(0.776, 0.604, 0.204))
    static let ink = adaptive(light: rgb(0.112, 0.122, 0.136), dark: rgb(0.906, 0.925, 0.948))
    static let muted = adaptive(light: rgb(0.410, 0.440, 0.480), dark: rgb(0.555, 0.596, 0.648))
    static let faint = adaptive(light: rgb(0.612, 0.642, 0.682), dark: rgb(0.373, 0.412, 0.462))
    static let separator = adaptive(light: rgba(0.000, 0.000, 0.000, 0.090), dark: rgba(1.000, 1.000, 1.000, 0.105))
    static let success = adaptive(light: rgb(0.141, 0.541, 0.361), dark: rgb(0.471, 0.902, 0.510))
    static let successSoft = adaptive(light: rgb(0.914, 0.965, 0.937), dark: rgb(0.058, 0.145, 0.075))

    static let readerCanvasNSColor = adaptiveNSColor(
        light: rgb(0.918, 0.918, 0.934),
        dark: rgb(0.010, 0.013, 0.017)
    )

    private typealias RGBA = (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> RGBA {
        rgba(red, green, blue, 1)
    }

    private static func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat) -> RGBA {
        (red, green, blue, alpha)
    }

    private static func adaptive(light: RGBA, dark: RGBA) -> Color {
        Color(nsColor: adaptiveNSColor(light: light, dark: dark))
    }

    private static func adaptiveNSColor(light: RGBA, dark: RGBA) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            let color = match == .darkAqua ? dark : light
            return NSColor(
                calibratedRed: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            )
        }
    }
}

import AppKit
import SwiftUI

enum NativeProTheme {
    static let window = adaptive(light: rgb(0.930, 0.948, 0.970), dark: rgb(0.006, 0.011, 0.015))
    static let commandRail = adaptive(light: rgb(0.948, 0.958, 0.972), dark: rgb(0.035, 0.042, 0.048))
    static let sidebar = adaptive(light: rgb(0.938, 0.950, 0.966), dark: rgb(0.048, 0.056, 0.064))
    static let readerCanvas = adaptive(light: rgb(0.906, 0.924, 0.946), dark: rgb(0.010, 0.013, 0.017))
    static let header = adaptive(light: rgba(0.970, 0.978, 0.990, 0.920), dark: rgba(0.105, 0.116, 0.129, 0.930))
    static let inspector = adaptive(light: rgb(0.952, 0.964, 0.980), dark: rgb(0.067, 0.076, 0.086))
    static let inspectorResearch = adaptive(light: rgb(0.944, 0.966, 0.960), dark: rgb(0.058, 0.074, 0.064))
    static let panel = adaptive(light: rgba(1.000, 1.000, 1.000, 0.780), dark: rgba(0.145, 0.160, 0.178, 0.900))
    static let tile = adaptive(light: rgb(0.914, 0.930, 0.952), dark: rgb(0.178, 0.195, 0.216))
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

import AppKit
import SwiftUI

enum NativeProTheme {
    static let window = adaptive(light: rgb(0.976, 0.976, 0.982), dark: rgb(0.020, 0.021, 0.022))
    static let commandRail = adaptive(light: rgb(0.966, 0.966, 0.974), dark: rgb(0.027, 0.028, 0.030))
    static let sidebar = adaptive(light: rgb(0.955, 0.955, 0.965), dark: rgb(0.036, 0.037, 0.040))
    static let readerCanvas = adaptive(light: rgb(0.918, 0.918, 0.934), dark: rgb(0.062, 0.064, 0.070))
    static let header = adaptive(light: rgb(0.984, 0.984, 0.990), dark: rgb(0.030, 0.031, 0.034))
    static let inspector = adaptive(light: rgb(0.980, 0.980, 0.987), dark: rgb(0.041, 0.043, 0.047))
    static let inspectorResearch = adaptive(light: rgb(0.972, 0.980, 0.988), dark: rgb(0.039, 0.047, 0.043))
    static let panel = adaptive(light: rgba(1.000, 1.000, 1.000, 0.760), dark: rgb(0.073, 0.076, 0.082))
    static let tile = adaptive(light: rgb(0.946, 0.946, 0.956), dark: rgb(0.103, 0.108, 0.116))
    static let accent = adaptive(light: rgb(0.000, 0.478, 1.000), dark: rgb(0.471, 0.902, 0.510))
    static let primaryButton = adaptive(light: rgb(0.000, 0.478, 1.000), dark: rgb(0.914, 0.922, 0.933))
    static let primaryButtonText = adaptive(light: rgb(1.000, 1.000, 1.000), dark: rgb(0.020, 0.021, 0.022))
    static let selection = adaptive(light: rgb(0.902, 0.941, 1.000), dark: rgb(0.086, 0.145, 0.098))
    static let searchHit = adaptive(light: rgb(1.000, 0.973, 0.843), dark: rgb(0.245, 0.176, 0.056))
    static let searchBorder = adaptive(light: rgb(0.929, 0.694, 0.180), dark: rgb(0.776, 0.604, 0.204))
    static let ink = adaptive(light: rgb(0.114, 0.114, 0.122), dark: rgb(0.914, 0.922, 0.933))
    static let muted = adaptive(light: rgb(0.431, 0.431, 0.451), dark: rgb(0.552, 0.574, 0.612))
    static let faint = adaptive(light: rgb(0.631, 0.631, 0.651), dark: rgb(0.380, 0.400, 0.430))
    static let separator = adaptive(light: rgba(0.000, 0.000, 0.000, 0.075), dark: rgba(1.000, 1.000, 1.000, 0.080))
    static let success = adaptive(light: rgb(0.141, 0.541, 0.361), dark: rgb(0.471, 0.902, 0.510))
    static let successSoft = adaptive(light: rgb(0.914, 0.965, 0.937), dark: rgb(0.058, 0.145, 0.075))

    static let readerCanvasNSColor = adaptiveNSColor(
        light: rgb(0.918, 0.918, 0.934),
        dark: rgb(0.062, 0.064, 0.070)
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

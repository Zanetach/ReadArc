import AppKit
import SwiftUI

enum NativeProTheme {
    static let window = adaptive(light: rgb255(0xF2, 0xF7, 0xFF), dark: rgb255(0x0B, 0x11, 0x18))
    static let commandRail = adaptive(light: rgb255(0xF9, 0xFB, 0xFF), dark: rgba255(0x17, 0x20, 0x2A, 0.940))
    static let commandRailShell = adaptive(light: rgb255(0xF2, 0xF7, 0xFF), dark: rgba255(0x0E, 0x16, 0x1F, 0.960))
    static let commandRailTile = adaptive(light: rgba255(0xFF, 0xFF, 0xFF, 0.001), dark: rgba255(0x2A, 0x35, 0x42, 0.760))
    static let commandRailTileActive = adaptive(light: rgba255(0xFF, 0xFF, 0xFF, 0.001), dark: rgba255(0x30, 0x3D, 0x4B, 0.860))
    static let sidebar = adaptive(light: rgb255(0xFA, 0xFC, 0xFF), dark: rgba255(0x13, 0x1C, 0x27, 0.960))
    static let readerCanvas = adaptive(light: rgb255(0xF5, 0xF8, 0xFE), dark: rgb255(0x0A, 0x0F, 0x16))
    static let header = adaptive(light: rgb255(0xFA, 0xFC, 0xFF), dark: rgba255(0x12, 0x1A, 0x23, 0.940))
    static let inspector = adaptive(light: rgb255(0xFF, 0xFF, 0xFF), dark: rgba255(0x14, 0x1D, 0x27, 0.960))
    static let inspectorResearch = adaptive(light: rgb255(0xFF, 0xFF, 0xFF), dark: rgba255(0x12, 0x1E, 0x25, 0.960))
    static let panel = adaptive(light: rgb255(0xFF, 0xFF, 0xFF), dark: rgba255(0x1B, 0x25, 0x31, 0.900))
    static let tile = adaptive(light: rgb255(0xFA, 0xFB, 0xFD), dark: rgba255(0x20, 0x2B, 0x39, 0.880))
    static let accent = adaptive(light: rgb255(0x2F, 0x6F, 0xFF), dark: rgb255(0x64, 0x95, 0xFF))
    static let primaryButton = adaptive(light: rgb(0.000, 0.478, 1.000), dark: rgb255(0x64, 0x95, 0xFF))
    static let primaryButtonText = adaptive(light: rgb(1.000, 1.000, 1.000), dark: rgb255(0x08, 0x10, 0x1A))
    static let selection = adaptive(light: rgb255(0xEA, 0xF1, 0xFF), dark: rgba255(0x18, 0x3D, 0x70, 0.920))
    static let searchHit = adaptive(light: rgb(1.000, 0.973, 0.843), dark: rgb255(0x58, 0x42, 0x12))
    static let searchBorder = adaptive(light: rgb(0.929, 0.694, 0.180), dark: rgb255(0xE5, 0xB8, 0x4D))
    static let ink = adaptive(light: rgb255(0x0E, 0x17, 0x36), dark: rgb255(0xEC, 0xF4, 0xFF))
    static let muted = adaptive(light: rgb255(0x75, 0x83, 0x9F), dark: rgb255(0xA3, 0xB2, 0xC6))
    static let faint = adaptive(light: rgb(0.600, 0.635, 0.690), dark: rgb255(0x62, 0x72, 0x86))
    static let separator = adaptive(light: rgba255(150, 160, 175, 0.220), dark: rgba255(0xB8, 0xC8, 0xE6, 0.145))
    static let success = adaptive(light: rgb(0.118, 0.620, 0.408), dark: rgb255(0x68, 0xE4, 0x9A))
    static let successSoft = adaptive(light: rgb(0.906, 0.965, 0.938), dark: rgb255(0x11, 0x33, 0x26))
    static let surfaceShadow = adaptive(light: rgba(0, 0, 0, 0.10), dark: rgba(0, 0, 0, 0.44))

    static let readerCanvasNSColor = adaptiveNSColor(
        light: rgb255(0xF3, 0xF4, 0xF6),
        dark: rgb255(0x08, 0x0D, 0x13)
    )

    private typealias RGBA = (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> RGBA {
        rgba(red, green, blue, 1)
    }

    private static func rgb255(_ red: Int, _ green: Int, _ blue: Int) -> RGBA {
        rgba255(red, green, blue, 1)
    }

    private static func rgba255(_ red: Int, _ green: Int, _ blue: Int, _ alpha: CGFloat) -> RGBA {
        rgba(CGFloat(red) / 255, CGFloat(green) / 255, CGFloat(blue) / 255, alpha)
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

import SwiftUI

struct ReadArcGlassContainer<Content: View>: View {
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}

extension View {
    @ViewBuilder
    func readArcGlass<S: Shape>(
        in shape: S,
        fallbackColor: Color,
        strokeColor: Color = NativeProTheme.separator,
        isInteractive: Bool = false,
        tint: Color? = nil,
        fallbackStrokeWidth: CGFloat = 1
    ) -> some View {
        let material: Material = isInteractive ? .regularMaterial : .thinMaterial
        background(material, in: shape)
            .background(fallbackColor, in: shape)
            .overlay {
                shape.stroke(strokeColor, lineWidth: fallbackStrokeWidth)
            }
    }
}

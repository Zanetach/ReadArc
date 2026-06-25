import SwiftUI

struct ReadArcGlassContainer<Content: View>: View {
    let spacing: CGFloat?
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}

extension View {
    func readArcGlass<S: Shape>(
        in shape: S,
        fallbackColor: Color,
        strokeColor: Color = NativeProTheme.separator,
        isInteractive: Bool = false,
        tint: Color? = nil,
        fallbackStrokeWidth: CGFloat = 1
    ) -> some View {
        modifier(
            ReadArcGlassModifier(
                shape: shape,
                fallbackColor: fallbackColor,
                strokeColor: strokeColor,
                isInteractive: isInteractive,
                tint: tint,
                fallbackStrokeWidth: fallbackStrokeWidth
            )
        )
    }
}

private struct ReadArcGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let fallbackColor: Color
    let strokeColor: Color
    let isInteractive: Bool
    let tint: Color?
    let fallbackStrokeWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .light {
            content
                .background(fallbackColor, in: shape)
                .overlay {
                    shape.fill(lightSheen)
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape.stroke(strokeColor, lineWidth: fallbackStrokeWidth)
                        .allowsHitTesting(false)
                }
        } else {
            let material: Material = isInteractive ? .thinMaterial : .ultraThinMaterial
            content
                .background(fallbackColor, in: shape)
                .background(material, in: shape)
                .overlay {
                    shape.fill(tint ?? Color.clear)
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape.fill(darkSheen)
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape.stroke(strokeColor, lineWidth: fallbackStrokeWidth)
                        .allowsHitTesting(false)
                }
        }
    }

    private var lightSheen: Color {
        if let tint {
            return tint.opacity(0.42)
        }
        return Color.white.opacity(isInteractive ? 0.10 : 0.06)
    }

    private var darkSheen: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(isInteractive ? 0.070 : 0.050),
                Color.white.opacity(0.018),
                Color.black.opacity(isInteractive ? 0.060 : 0.090)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

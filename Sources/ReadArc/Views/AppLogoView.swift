import SwiftUI

struct AppLogoView: View {
    let size: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ZStack {
            background
            openDocument
            citationOrbit
            citationNodes
            spark
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isDark
                        ? [
                            Color(red: 0.031, green: 0.067, blue: 0.122),
                            Color(red: 0.063, green: 0.137, blue: 0.231),
                            Color(red: 0.055, green: 0.227, blue: 0.184)
                        ]
                        : [
                            Color(red: 1.000, green: 0.973, blue: 0.910),
                            Color(red: 0.918, green: 0.953, blue: 1.000),
                            Color(red: 0.831, green: 1.000, blue: 0.910)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .stroke(Color.white.opacity(isDark ? 0.14 : 0.78), lineWidth: max(1, size * 0.024))
            }
            .shadow(color: Color(red: 0.102, green: 0.251, blue: 0.416).opacity(isDark ? 0.36 : 0.16), radius: size * 0.15, y: size * 0.06)
    }

    private var openDocument: some View {
        ZStack {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: size * 0.075, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.929, green: 0.965, blue: 1.000)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: size * 0.075, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.980, green: 0.992, blue: 1.000),
                                Color(red: 0.929, green: 0.984, blue: 0.949)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: size * 0.58, height: size * 0.52)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.075, style: .continuous))
            .shadow(color: Color(red: 0.121, green: 0.231, blue: 0.341).opacity(isDark ? 0.30 : 0.16), radius: size * 0.10, y: size * 0.04)

            Capsule()
                .fill(Color(red: 0.792, green: 0.839, blue: 0.894).opacity(0.72))
                .frame(width: max(1, size * 0.012), height: size * 0.50)

            Capsule()
                .fill(Color(red: 0.043, green: 0.518, blue: 1.000))
                .frame(width: size * 0.15, height: max(2, size * 0.03))
                .offset(x: -size * 0.15, y: -size * 0.15)

            Capsule()
                .fill(Color(red: 0.361, green: 0.659, blue: 0.969))
                .frame(width: size * 0.15, height: max(2, size * 0.03))
                .offset(x: size * 0.15, y: -size * 0.15)

            line(width: 0.13, x: -0.145, y: -0.065, opacity: 0.28)
            line(width: 0.13, x: 0.145, y: -0.065, opacity: 0.24)
            line(width: 0.11, x: -0.16, y: 0.045, opacity: 0.20)
            line(width: 0.11, x: 0.16, y: 0.045, opacity: 0.18)

            bookmark
        }
        .offset(y: -size * 0.015)
    }

    private func line(width: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(Color(red: 0.541, green: 0.580, blue: 0.651).opacity(opacity))
            .frame(width: size * width, height: max(1.4, size * 0.022))
            .offset(x: size * x, y: size * y)
    }

    private var bookmark: some View {
        Path { path in
            let x = size * 0.27
            let y = -size * 0.255
            let w = size * 0.105
            let h = size * 0.135
            path.move(to: CGPoint(x: size / 2 + x, y: size / 2 + y))
            path.addLine(to: CGPoint(x: size / 2 + x + w, y: size / 2 + y))
            path.addLine(to: CGPoint(x: size / 2 + x + w, y: size / 2 + y + h))
            path.addLine(to: CGPoint(x: size / 2 + x + w * 0.5, y: size / 2 + y + h * 0.68))
            path.addLine(to: CGPoint(x: size / 2 + x, y: size / 2 + y + h))
            path.closeSubpath()
        }
        .fill(Color(red: 1.000, green: 0.714, blue: 0.153))
    }

    private var citationOrbit: some View {
        ZStack {
            orbitPath(yOffset: size * 0.014)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.306, green: 0.902, blue: 0.647),
                            Color(red: 0.490, green: 0.976, blue: 0.773),
                            Color(red: 0.208, green: 0.827, blue: 0.600)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: max(2, size * 0.045), lineCap: .round, lineJoin: .round)
                )

            orbitPath(yOffset: 0)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.067, green: 0.094, blue: 0.153),
                            Color(red: 0.059, green: 0.122, blue: 0.220),
                            Color(red: 0.071, green: 0.153, blue: 0.122)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: max(2.4, size * 0.045), lineCap: .round, lineJoin: .round)
                )
        }
    }

    private func orbitPath(yOffset: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: size * 0.26, y: size * 0.68 + yOffset))
            path.addCurve(
                to: CGPoint(x: size * 0.82, y: size * 0.64 + yOffset),
                control1: CGPoint(x: size * 0.36, y: size * 0.59 + yOffset),
                control2: CGPoint(x: size * 0.59, y: size * 0.53 + yOffset)
            )
        }
    }

    private var citationNodes: some View {
        ZStack {
            node(color: Color(red: 1.000, green: 0.714, blue: 0.153), diameter: 0.112, x: 0.36, y: 0.625)
            node(color: Color(red: 0.043, green: 0.518, blue: 1.000), diameter: 0.120, x: 0.54, y: 0.565)
            node(color: Color(red: 0.165, green: 0.549, blue: 0.333), diameter: 0.112, x: 0.715, y: 0.600)
        }
    }

    private func node(color: Color, diameter: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size * diameter, height: size * diameter)
            .overlay {
                Circle()
                    .stroke(Color(red: 0.067, green: 0.094, blue: 0.153), lineWidth: max(1.4, size * 0.018))
            }
            .position(x: size * x, y: size * y)
    }

    private var spark: some View {
        Path { path in
            let center = CGPoint(x: size * 0.30, y: size * 0.31)
            path.move(to: CGPoint(x: center.x, y: center.y - size * 0.055))
            path.addLine(to: CGPoint(x: center.x + size * 0.020, y: center.y - size * 0.016))
            path.addLine(to: CGPoint(x: center.x + size * 0.056, y: center.y))
            path.addLine(to: CGPoint(x: center.x + size * 0.020, y: center.y + size * 0.016))
            path.addLine(to: CGPoint(x: center.x, y: center.y + size * 0.055))
            path.addLine(to: CGPoint(x: center.x - size * 0.020, y: center.y + size * 0.016))
            path.addLine(to: CGPoint(x: center.x - size * 0.056, y: center.y))
            path.addLine(to: CGPoint(x: center.x - size * 0.020, y: center.y - size * 0.016))
            path.closeSubpath()
        }
        .fill(isDark ? Color(red: 0.490, green: 0.827, blue: 0.988) : Color(red: 0.043, green: 0.518, blue: 1.000))
    }
}

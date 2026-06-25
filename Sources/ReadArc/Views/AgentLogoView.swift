import SwiftUI

struct AgentLogoView: View {
    let agent: ChatAgentProvider
    var size: CGFloat = 24
    var showsPlate = true

    var body: some View {
        ZStack {
            if showsPlate {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(backgroundGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .stroke(borderColor, lineWidth: max(1, size * 0.045))
                    }
            }

            mark
                .frame(width: size * 0.62, height: size * 0.62)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var mark: some View {
        switch agent {
        case .codexCLI:
            CodexAgentMark()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.105, green: 0.443, blue: 1.000), Color(red: 0.160, green: 0.760, blue: 0.690)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .claudeCode:
            ClaudeCodeAgentMark()
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.490, green: 0.270, blue: 0.980), Color(red: 0.980, green: 0.420, blue: 0.530)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var backgroundGradient: LinearGradient {
        switch agent {
        case .codexCLI:
            return LinearGradient(
                colors: [Color(red: 0.914, green: 0.956, blue: 1.000), Color(red: 0.898, green: 1.000, blue: 0.974)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .claudeCode:
            return LinearGradient(
                colors: [Color(red: 0.948, green: 0.922, blue: 1.000), Color(red: 1.000, green: 0.930, blue: 0.950)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        switch agent {
        case .codexCLI:
            return Color(red: 0.180, green: 0.520, blue: 1.000).opacity(0.18)
        case .claudeCode:
            return Color(red: 0.650, green: 0.380, blue: 1.000).opacity(0.18)
        }
    }
}

private struct CodexAgentMark: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height)
        let stroke = unit * 0.18
        let radius = stroke * 0.66
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = [
            CGPoint(x: center.x, y: rect.minY + stroke * 0.92),
            CGPoint(x: rect.maxX - stroke * 0.70, y: center.y - stroke * 0.12),
            CGPoint(x: rect.maxX - stroke * 0.70, y: center.y + stroke * 0.98),
            CGPoint(x: center.x, y: rect.maxY - stroke * 0.92),
            CGPoint(x: rect.minX + stroke * 0.70, y: center.y + stroke * 0.12),
            CGPoint(x: rect.minX + stroke * 0.70, y: center.y - stroke * 0.98)
        ]

        var path = Path()
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            path.move(to: current)
            path.addLine(to: next)
        }

        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        return path.strokedPath(.init(lineWidth: stroke, lineCap: .round, lineJoin: .round))
    }
}

private struct ClaudeCodeAgentMark: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height)
        let line = unit * 0.17
        let inset = unit * 0.08
        let midY = rect.midY

        var path = Path()

        path.move(to: CGPoint(x: rect.minX + unit * 0.42, y: rect.minY + inset))
        path.addCurve(
            to: CGPoint(x: rect.minX + unit * 0.22, y: midY),
            control1: CGPoint(x: rect.minX + unit * 0.20, y: rect.minY + unit * 0.16),
            control2: CGPoint(x: rect.minX + unit * 0.30, y: rect.minY + unit * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + unit * 0.42, y: rect.maxY - inset),
            control1: CGPoint(x: rect.minX + unit * 0.30, y: rect.maxY - unit * 0.42),
            control2: CGPoint(x: rect.minX + unit * 0.20, y: rect.maxY - unit * 0.16)
        )

        path.move(to: CGPoint(x: rect.maxX - unit * 0.42, y: rect.minY + inset))
        path.addCurve(
            to: CGPoint(x: rect.maxX - unit * 0.22, y: midY),
            control1: CGPoint(x: rect.maxX - unit * 0.20, y: rect.minY + unit * 0.16),
            control2: CGPoint(x: rect.maxX - unit * 0.30, y: rect.minY + unit * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - unit * 0.42, y: rect.maxY - inset),
            control1: CGPoint(x: rect.maxX - unit * 0.30, y: rect.maxY - unit * 0.42),
            control2: CGPoint(x: rect.maxX - unit * 0.20, y: rect.maxY - unit * 0.16)
        )

        path.move(to: CGPoint(x: rect.midX - unit * 0.08, y: rect.minY + unit * 0.30))
        path.addLine(to: CGPoint(x: rect.midX + unit * 0.08, y: rect.maxY - unit * 0.30))

        return path.strokedPath(.init(lineWidth: line, lineCap: .round, lineJoin: .round))
    }
}

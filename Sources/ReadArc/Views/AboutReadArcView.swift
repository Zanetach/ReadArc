import SwiftUI

struct AboutReadArcView: View {
    let repositoryURL: URL?

    private var versionText: String {
        "Version \(Bundle.main.readArcDisplayVersion)"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                AppLogoView(size: 66)
                    .padding(.top, 8)

                VStack(spacing: 5) {
                    Text("ReadArc")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(NativeProTheme.ink)

                    Text(versionText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NativeProTheme.muted)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 18)

            VStack(spacing: 12) {
                AboutInfoRow(title: "Author", value: "Zanetach")
                AboutInfoRow(title: "Repository", value: "Zanetach/ReadArc")

                Button {
                    if let repositoryURL {
                        NSWorkspace.shared.open(repositoryURL)
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Star")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .foregroundStyle(NativeProTheme.primaryButtonText)
                    .readArcGlass(
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous),
                        fallbackColor: NativeProTheme.accent,
                        strokeColor: Color.white.opacity(0.20),
                        isInteractive: true,
                        tint: NativeProTheme.accent.opacity(0.24)
                    )
                }
                .buttonStyle(.plain)
                .disabled(repositoryURL == nil)
                .help("Open GitHub repository")
            }
            .padding(14)
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                fallbackColor: NativeProTheme.panel.opacity(0.74),
                strokeColor: NativeProTheme.separator
            )
            .padding(.horizontal, 22)

            Text("Copyright © 2026 Zanetach")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NativeProTheme.faint)
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
        .frame(width: 320)
        .background(NativeProTheme.inspector.opacity(0.92))
    }
}

private struct AboutInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NativeProTheme.muted)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NativeProTheme.ink)
                .lineLimit(1)
        }
    }
}

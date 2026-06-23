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
                    .background(NativeProTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(repositoryURL == nil)
                .help("Open GitHub repository")
            }
            .padding(14)
            .background(NativeProTheme.panel.opacity(0.74), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativeProTheme.separator, lineWidth: 1)
            }
            .padding(.horizontal, 22)

            Text("Copyright © 2026 Zanetach")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NativeProTheme.faint)
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
        .frame(width: 320)
        .background(NativeProTheme.inspector)
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

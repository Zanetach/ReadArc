import SwiftUI

struct DetailView: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoadingDocument {
                LoadingDocumentView(title: model.documentTitle)
            } else if model.document == nil {
                EmptyDocumentView(openDocument: model.openDocument)
            } else {
                PDFKitRepresentedView(model: model)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
        .background {
            ReaderCanvasBackground(isFocusMode: model.readerMode == .focus)
        }
        .navigationTitle(model.documentURL?.lastPathComponent ?? "ReadArc")
    }
}

private struct ReaderCanvasBackground: View {
    let isFocusMode: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            NativeProTheme.readerCanvas
                .opacity(isFocusMode ? 0.58 : 0.66)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear,
                    NativeProTheme.accent.opacity(0.028)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
    }
}

private struct LoadingDocumentView: View {
    let title: String
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 5) {
                Text(language.text("loadingPDF"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(NativeProTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderCanvasBackground(isFocusMode: false))
    }
}

private struct EmptyDocumentView: View {
    let openDocument: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        ReadArcGlassContainer(spacing: 14) {
            VStack(spacing: 18) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 62, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(NativeProTheme.muted)
                    .frame(width: 94, height: 94)
                    .readArcGlass(
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                        fallbackColor: NativeProTheme.panel.opacity(0.34),
                        strokeColor: NativeProTheme.separator.opacity(0.50)
                    )

                VStack(spacing: 7) {
                    Text(language.text("empty.title"))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(NativeProTheme.ink)

                    Text(language.text("empty.subtitle"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(NativeProTheme.muted)
                }

                Button {
                    openDocument()
                } label: {
                    Label(language.text("openPDF"), systemImage: "folder")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("o")
                .foregroundStyle(NativeProTheme.accent)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous),
                    fallbackColor: NativeProTheme.panel.opacity(0.36),
                    strokeColor: NativeProTheme.accent.opacity(0.18),
                    isInteractive: true,
                    tint: NativeProTheme.accent.opacity(0.12)
                )
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: 28, style: .continuous),
                fallbackColor: NativeProTheme.panel.opacity(0.18),
                strokeColor: NativeProTheme.separator.opacity(0.35)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderCanvasBackground(isFocusMode: false))
    }
}

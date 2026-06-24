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
        .background(model.readerMode == .focus ? NativeProTheme.readerCanvas.opacity(0.82) : NativeProTheme.readerCanvas)
        .navigationTitle(model.documentURL?.lastPathComponent ?? "ReadArc")
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
        .background(NativeProTheme.readerCanvas)
    }
}

private struct EmptyDocumentView: View {
    let openDocument: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 74, weight: .regular))
                .foregroundStyle(NativeProTheme.muted)

            VStack(spacing: 8) {
                Text(language.text("empty.title"))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)

                Text(language.text("empty.subtitle"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)
            }

            Button {
                openDocument()
            } label: {
                Label(language.text("openPDF"), systemImage: "folder")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o")
            .foregroundStyle(NativeProTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NativeProTheme.readerCanvas)
    }
}

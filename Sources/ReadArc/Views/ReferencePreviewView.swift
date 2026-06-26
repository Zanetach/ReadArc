import SwiftUI

enum ReferencePreviewMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["READARC_REFERENCE_PREVIEW"] == "1"
    }
}

struct ReferencePreviewView: View {
    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 2048, proxy.size.height / 1152)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.961, green: 0.980, blue: 1.000),
                        Color(red: 0.938, green: 0.970, blue: 1.000),
                        Color(red: 0.984, green: 0.992, blue: 1.000)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 22 * scale) {
                    ReferenceToolbar(scale: scale)
                        .frame(height: 92 * scale)

                    HStack(alignment: .top, spacing: 30 * scale) {
                        ReferenceRail(scale: scale)
                            .frame(width: 86 * scale, height: 690 * scale)
                            .padding(.top, 76 * scale)

                        ReferenceThumbnailPanel(scale: scale)
                            .frame(width: 366 * scale)

                        ReferencePDFCanvas(scale: scale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ReferenceResearchPanel(scale: scale)
                            .frame(width: 654 * scale)
                    }
                    .padding(.leading, 28 * scale)
                    .padding(.trailing, 34 * scale)
                    .padding(.bottom, 26 * scale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ReferenceToolbar: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 20 * scale) {
            Spacer()
                .frame(width: 126 * scale)

            HStack(spacing: 16 * scale) {
                AppLogoView(size: 52 * scale)
                Text("ReadArc")
                    .font(.system(size: 28 * scale, weight: .semibold))
                    .foregroundStyle(NativeProTheme.ink)
            }
            .frame(width: 246 * scale, alignment: .leading)

            ReferenceSegment(width: 236 * scale, scale: scale) {
                ToolbarIcon("chevron.left", scale: scale)
                DividerLine(scale: scale)
                Text("18 / 142")
                    .font(.system(size: 16 * scale, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                DividerLine(scale: scale)
                ToolbarIcon("chevron.right", scale: scale)
            }

            ReferenceSegment(width: 206 * scale, scale: scale) {
                ToolbarIcon("minus", scale: scale)
                DividerLine(scale: scale)
                Text("92%")
                    .font(.system(size: 16 * scale, weight: .semibold, design: .monospaced))
                    .frame(width: 64 * scale)
                DividerLine(scale: scale)
                ToolbarIcon("plus", scale: scale)
                DividerLine(scale: scale)
                ToolbarIcon("chevron.down", scale: scale, size: 13)
            }

            ReferenceButton(systemImage: "arrow.up.left.and.arrow.down.right", scale: scale)

            ReferenceSegment(width: 350 * scale, scale: scale) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17 * scale, weight: .medium))
                Text("vector database")
                    .font(.system(size: 16 * scale, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundStyle(NativeProTheme.muted)
            }

            Text("24 matches")
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(NativeProTheme.ink)
                .frame(width: 118 * scale)

            ReferenceSegment(width: 104 * scale, scale: scale) {
                ToolbarIcon("chevron.up", scale: scale)
                DividerLine(scale: scale)
                ToolbarIcon("chevron.down", scale: scale)
            }

            Spacer(minLength: 16 * scale)

            ReferenceSegment(width: 126 * scale, scale: scale) {
                Image(systemName: "globe")
                    .font(.system(size: 18 * scale, weight: .medium))
                Text("EN")
                    .font(.system(size: 16 * scale, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12 * scale, weight: .bold))
            }

            ReferenceButton(systemImage: "sun.max", scale: scale)
            ReferenceButton(systemImage: "sidebar.right", scale: scale, isActive: true)
        }
        .padding(.trailing, 36 * scale)
        .foregroundStyle(NativeProTheme.ink)
    }
}

private struct ReferenceSegment<Content: View>: View {
    let width: CGFloat
    let scale: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            content()
        }
        .frame(width: width, height: 52 * scale)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                .stroke(NativeProTheme.separator.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 8 * scale, y: 4 * scale)
    }
}

private struct ReferenceButton: View {
    let systemImage: String
    let scale: CGFloat
    var isActive = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 19 * scale, weight: .semibold))
            .frame(width: 52 * scale, height: 52 * scale)
            .foregroundStyle(isActive ? NativeProTheme.accent : NativeProTheme.ink)
            .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                    .stroke(NativeProTheme.separator.opacity(0.62), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 8 * scale, y: 4 * scale)
    }
}

private struct ToolbarIcon: View {
    let systemImage: String
    let scale: CGFloat
    var size: CGFloat = 18

    init(_ systemImage: String, scale: CGFloat, size: CGFloat = 18) {
        self.systemImage = systemImage
        self.scale = scale
        self.size = size
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * scale, weight: .semibold))
            .frame(width: 52 * scale, height: 52 * scale)
    }
}

private struct DividerLine: View {
    let scale: CGFloat

    var body: some View {
        Rectangle()
            .fill(NativeProTheme.separator.opacity(0.72))
            .frame(width: 1, height: 30 * scale)
    }
}

private struct ReferenceRail: View {
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 54 * scale) {
            railIcon("bubble.left.and.bubble.right")
            railIcon("folder")
            railIcon("sidebar.left", active: true)
            railIcon("magnifyingglass")
            railIcon("doc.text")
            railIcon("list.bullet.rectangle")
        }
        .padding(.vertical, 50 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(.white.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 22 * scale, y: 14 * scale)
    }

    private func railIcon(_ systemImage: String, active: Bool = false) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 27 * scale, weight: .regular))
            .foregroundStyle(active ? NativeProTheme.accent : NativeProTheme.muted)
            .frame(width: 58 * scale, height: 58 * scale)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 13 * scale, style: .continuous)
                        .fill(NativeProTheme.selection.opacity(0.96))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13 * scale, style: .continuous)
                                .stroke(NativeProTheme.accent.opacity(0.16), lineWidth: 1)
                        }
                }
            }
    }
}

private struct ReferenceThumbnailPanel: View {
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * scale) {
            HStack {
                Text("Thumbnails")
                    .font(.system(size: 22 * scale, weight: .semibold))
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 18 * scale, weight: .bold))
            }
            .padding(.top, 32 * scale)
            .padding(.horizontal, 30 * scale)

            HStack(spacing: 10 * scale) {
                Image(systemName: "magnifyingglass")
                Text("Search pages")
                    .foregroundStyle(NativeProTheme.muted)
                Spacer()
            }
            .font(.system(size: 15 * scale, weight: .medium))
            .padding(.horizontal, 15 * scale)
            .frame(height: 48 * scale)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                    .stroke(NativeProTheme.separator.opacity(0.58), lineWidth: 1)
            }
            .padding(.horizontal, 28 * scale)

            HStack(spacing: 10 * scale) {
                chip("All", active: true)
                chip("Quotes")
                chip("Specs")
            }
            .padding(.horizontal, 30 * scale)

            VStack(spacing: 12 * scale) {
                ReferenceThumbRow(page: "16", selected: false, chart: true, scale: scale)
                ReferenceThumbRow(page: "17", selected: false, scale: scale)
                ReferenceThumbRow(page: "18", selected: true, highlight: true, scale: scale)
                ReferenceThumbRow(page: "19", selected: false, scale: scale)
                ReferenceThumbRow(page: "20", selected: false, chart: true, scale: scale)
            }
            .padding(.horizontal, 20 * scale)

            Spacer(minLength: 0)
        }
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
                .stroke(.white.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 24 * scale, y: 14 * scale)
    }

    private func chip(_ title: String, active: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 13 * scale, weight: .semibold))
            .foregroundStyle(active ? Color.white : NativeProTheme.ink)
            .padding(.horizontal, 20 * scale)
            .frame(height: 34 * scale)
            .background(active ? NativeProTheme.accent : NativeProTheme.tile.opacity(0.80), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(active ? NativeProTheme.accent.opacity(0.10) : NativeProTheme.separator.opacity(0.52), lineWidth: 1)
            }
    }
}

private struct ReferenceThumbRow: View {
    let page: String
    var selected = false
    var highlight = false
    var chart = false
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 16 * scale) {
            Text(page)
                .font(.system(size: 17 * scale, weight: .semibold, design: .monospaced))
                .foregroundStyle(selected ? NativeProTheme.accent : NativeProTheme.muted)
                .frame(width: 32 * scale)

            miniPage
                .frame(width: 190 * scale, height: 116 * scale)
                .background(.white, in: RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 12 * scale, y: 6 * scale)
        }
        .padding(.horizontal, 8 * scale)
        .padding(.vertical, 10 * scale)
        .background(selected ? NativeProTheme.selection.opacity(0.35) : Color.clear, in: RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                    .stroke(NativeProTheme.accent, lineWidth: 2 * scale)
            }
        }
    }

    private var miniPage: some View {
        VStack(spacing: 5 * scale) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index == 1 && highlight ? NativeProTheme.searchHit : NativeProTheme.ink.opacity(0.22))
                    .frame(width: (index % 2 == 0 ? 108 : 132) * scale, height: 2 * scale)
            }
            if chart {
                Path { path in
                    path.move(to: CGPoint(x: 20 * scale, y: 32 * scale))
                    path.addLine(to: CGPoint(x: 142 * scale, y: 32 * scale))
                    path.move(to: CGPoint(x: 20 * scale, y: 32 * scale))
                    path.addLine(to: CGPoint(x: 20 * scale, y: 6 * scale))
                    path.move(to: CGPoint(x: 24 * scale, y: 28 * scale))
                    path.addCurve(to: CGPoint(x: 136 * scale, y: 8 * scale), control1: CGPoint(x: 72 * scale, y: 30 * scale), control2: CGPoint(x: 102 * scale, y: 30 * scale))
                }
                .stroke(NativeProTheme.accent.opacity(0.55), lineWidth: 1.2 * scale)
                .frame(width: 160 * scale, height: 40 * scale)
            }
        }
        .padding(18 * scale)
    }
}

private struct ReferencePDFCanvas: View {
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            ReferencePDFPage(scale: scale)
                .padding(.top, 16 * scale)
                .padding(.bottom, 26 * scale)

            HStack(spacing: 0) {
                bottomIcon("cursorarrow")
                DividerLine(scale: scale)
                bottomIcon("hand.raised")
                DividerLine(scale: scale)
                bottomIcon("minus")
                DividerLine(scale: scale)
                bottomIcon("plus.magnifyingglass")
                DividerLine(scale: scale)
                bottomIcon("plus")
                DividerLine(scale: scale)
                bottomIcon("ellipsis")
            }
            .padding(.horizontal, 14 * scale)
            .frame(height: 64 * scale)
            .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 17 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17 * scale, style: .continuous)
                    .stroke(NativeProTheme.separator.opacity(0.50), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 18 * scale, y: 10 * scale)
            .padding(.bottom, 20 * scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 22 * scale, y: 12 * scale)
    }

    private func bottomIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20 * scale, weight: .semibold))
            .frame(width: 58 * scale, height: 64 * scale)
            .foregroundStyle(NativeProTheme.ink)
    }
}

private struct ReferencePDFPage: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            Color.white
            VStack(alignment: .leading, spacing: 16 * scale) {
                HStack {
                    Text("3.2.2")
                    Text("Vector Database Architectures")
                        .fontWeight(.bold)
                    Spacer()
                    Text("18")
                }
                .font(.custom("Times New Roman", size: 15 * scale))

                paragraph([
                    ("A ", false, false),
                    ("vector database", true, false),
                    (" is a specialized database designed to store, index, and query high-dimensional vector embeddings efficiently. Unlike traditional databases, which rely on exact-match or keyword-based retrieval, vector databases excel at ", false, false),
                    ("similarity search", false, true),
                    (" over continuous vector spaces.", false, false)
                ])

                Text("Typical architecture components include:")
                    .font(.custom("Times New Roman", size: 15 * scale))

                bullet("Storage Layer:  Persists vectors and metadata.")
                bullet("Indexing Layer:  Builds ANN (Approximate Nearest Neighbor) indexes such as HNSW, IVF-PQ, or ScaNN.", highlight: true)
                bullet("Query Layer:  Handles embedding input, similarity search, and filtering.")
                bullet("Metadata Layer:  Supports structured filters and hybrid queries.")

                paragraph([
                    ("The choice of index structure affects the trade-off between recall, latency, and memory usage. ", false, false),
                    ("HNSW", false, true),
                    (" provides high recall with logarithmic search complexity, while ", false, false),
                    ("IVF-PQ", false, true),
                    (" compresses vectors to reduce memory footprint.", false, false)
                ])

                Text("3.2.3   Similarity Search")
                    .font(.custom("Times New Roman", size: 17 * scale).weight(.bold))
                    .padding(.top, 12 * scale)

                Text("Similarity search returns the top-k vectors most similar to a query vector q. Common similarity metrics include:")
                    .font(.custom("Times New Roman", size: 15 * scale))

                bullet("Cosine Similarity:  sim(q, x) =  q · x / ||q||||x||")
                bullet("Dot Product:  sim(q, x) = q · x")
                bullet("Euclidean Distance:  sim(q, x) = -||q - x||2")

                Text("In practice, cosine similarity is the most widely used for embedding-based retrieval.")
                    .font(.custom("Times New Roman", size: 15 * scale))

                Spacer()
            }
            .padding(.horizontal, 128 * scale)
            .padding(.top, 70 * scale)
            .padding(.bottom, 80 * scale)

            noteBox(title: "Note", body: "Vector DBs enable\nsemantic search at\nscale.", color: Color.purple, x: -315, y: -230)
            noteBox(title: "", body: "HNSW balances\nrecall and latency\nwell for most use\ncases.", color: NativeProTheme.success, x: 330, y: -8)
        }
        .frame(width: 760 * scale, height: 930 * scale)
    }

    private func paragraph(_ runs: [(String, Bool, Bool)]) -> some View {
        runs.reduce(Text("")) { partial, run in
            partial + Text(run.0)
                .foregroundStyle(run.2 ? NativeProTheme.accent : NativeProTheme.ink)
        }
        .font(.custom("Times New Roman", size: 15 * scale))
        .lineSpacing(5 * scale)
    }

    private func bullet(_ text: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12 * scale) {
            Text("•")
            Text(text)
                .background(highlight ? NativeProTheme.searchHit : Color.clear)
        }
        .font(.custom("Times New Roman", size: 15 * scale))
    }

    private func noteBox(title: String, body: String, color: Color, x: CGFloat, y: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 12 * scale, weight: .semibold))
            }
            Text(body)
                .font(.system(size: 11 * scale, weight: .semibold))
                .lineSpacing(5 * scale)
        }
        .foregroundStyle(color)
        .padding(12 * scale)
        .frame(width: 104 * scale, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        }
        .offset(x: x * scale, y: y * scale)
    }
}

private struct ReferenceResearchPanel: View {
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 16 * scale) {
            ReferenceTabs(scale: scale)
                .padding(.top, 26 * scale)
                .padding(.horizontal, 24 * scale)

            HStack(spacing: 10 * scale) {
                Text("Agent")
                    .font(.system(size: 15 * scale, weight: .semibold))
                pill("Codex", active: true)
                pill("Claude Code")
                Spacer()
            }
            .padding(.horizontal, 28 * scale)

            HStack(spacing: 12 * scale) {
                metric("doc.text", "142", "Pages")
                metric("magnifyingglass", "24", "Matches")
                metric("list.bullet", "9", "Outline")
                metric("doc", "18.4 MB", "File Size")
            }
            .padding(.horizontal, 20 * scale)

            infoCard(title: "Summary", icon: "sparkles", trailing: "Copy") {
                Text("This paper introduces vector database architectures and similarity\nsearch techniques. It covers index structures (HNSW, IVF-PQ,\nScaNN), similarity metrics, and practical trade-offs.")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .lineSpacing(4 * scale)
            }

            infoCard(title: "Search Matches (24)", icon: "list.bullet", trailing: "View all") {
                matchRow("P. 18", "...A vector database is a specialized database designed to store,\nindex, and query high-dimensional vector embeddings efficiently...")
                matchRow("P. 21", "...we adopt HNSW index in our vector database to achieve high\nrecall with logarithmic search complexity...")
                matchRow("P. 33", "...Hybrid search combines keyword retrieval with vector database\nsimilarity search for better relevance...")
            }

            infoCard(title: "Outline (9)", icon: "doc.text", trailing: "View all") {
                outlineRow("›", "1", "Introduction")
                outlineRow("›", "2", "Background")
                outlineRow("⌄", "3", "Vector Database Architecture")
                outlineRow("", "3.1", "System Overview", indent: 22)
                outlineRow("", "3.2", "Indexing Strategies", indent: 22)
                outlineRow("", "3.2.2", "Vector Database Architectures    (current)", indent: 34, active: true)
                outlineRow("", "3.2.3", "Similarity Search", indent: 34)
            }

            Spacer(minLength: 0)
        }
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 28 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
                .stroke(.white.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 24 * scale, y: 14 * scale)
    }

    private func pill(_ title: String, active: Bool = false) -> some View {
        HStack(spacing: 7 * scale) {
            Circle()
                .fill(active ? NativeProTheme.success : Color.clear)
                .frame(width: 9 * scale, height: 9 * scale)
                .overlay {
                    Circle().stroke(active ? .clear : NativeProTheme.muted.opacity(0.45), lineWidth: 1)
                }
            Text(title)
                .font(.system(size: 13 * scale, weight: .semibold))
        }
        .foregroundStyle(active ? NativeProTheme.ink : NativeProTheme.muted)
        .padding(.horizontal, 13 * scale)
        .frame(height: 30 * scale)
        .background(.white.opacity(0.72), in: Capsule())
        .overlay { Capsule().stroke(NativeProTheme.separator.opacity(0.50), lineWidth: 1) }
    }

    private func metric(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 8 * scale) {
            Image(systemName: icon)
                .font(.system(size: 25 * scale, weight: .regular))
                .foregroundStyle(NativeProTheme.accent)
            Text(value)
                .font(.system(size: 18 * scale, weight: .semibold))
            Text(label)
                .font(.system(size: 12 * scale, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 116 * scale)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16 * scale).stroke(NativeProTheme.separator.opacity(0.48), lineWidth: 1) }
    }

    private func infoCard<Content: View>(title: String, icon: String, trailing: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(icon == "sparkles" ? NativeProTheme.success : NativeProTheme.accent)
                Text(title)
                    .font(.system(size: 16 * scale, weight: .semibold))
                Spacer()
                Text(trailing)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(trailing == "Copy" ? NativeProTheme.ink.opacity(0.68) : NativeProTheme.accent)
            }
            content()
        }
        .padding(16 * scale)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18 * scale).stroke(NativeProTheme.separator.opacity(0.46), lineWidth: 1) }
        .padding(.horizontal, 20 * scale)
    }

    private func matchRow(_ page: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12 * scale) {
            Text(page)
                .font(.system(size: 13 * scale, weight: .semibold))
                .padding(.horizontal, 9 * scale)
                .frame(height: 24 * scale)
                .background(NativeProTheme.selection.opacity(0.78), in: Capsule())
            Text(text)
                .font(.system(size: 13 * scale, weight: .semibold))
                .lineLimit(2)
        }
    }

    private func outlineRow(_ disclosure: String, _ number: String, _ text: String, indent: CGFloat = 0, active: Bool = false) -> some View {
        HStack(spacing: 10 * scale) {
            Text(disclosure).frame(width: 12 * scale)
            Text(number).frame(width: 42 * scale, alignment: .leading)
            Text(text)
            Spacer()
        }
        .font(.system(size: 13 * scale, weight: active ? .semibold : .medium))
        .foregroundStyle(active ? NativeProTheme.accent : NativeProTheme.ink)
        .padding(.leading, indent * scale)
        .padding(.horizontal, active ? 8 * scale : 0)
        .frame(height: 20 * scale)
        .background(active ? NativeProTheme.selection.opacity(0.86) : Color.clear, in: RoundedRectangle(cornerRadius: 6 * scale))
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13 * scale, weight: .semibold))
            .padding(.horizontal, 13 * scale)
            .frame(height: 30 * scale)
            .background(NativeProTheme.selection.opacity(0.80), in: Capsule())
    }
}

private struct ReferenceTabs: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            tab("Chat")
            Rectangle().fill(NativeProTheme.separator.opacity(0.78)).frame(width: 1, height: 18 * scale).padding(.horizontal, 8 * scale)
            tab("Focus")
            Rectangle().fill(NativeProTheme.separator.opacity(0.78)).frame(width: 1, height: 18 * scale).padding(.horizontal, 8 * scale)
            tab("Research", active: true)
        }
        .padding(4 * scale)
        .frame(height: 48 * scale)
        .background(NativeProTheme.tile.opacity(0.74), in: RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22 * scale).stroke(NativeProTheme.separator.opacity(0.50), lineWidth: 1) }
    }

    private func tab(_ title: String, active: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 14 * scale, weight: .semibold))
            .foregroundStyle(active ? Color.white : NativeProTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 38 * scale)
            .background(active ? NativeProTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
    }
}

import Foundation

public struct AgentPDFPageExcerpt: Equatable, Sendable {
    public let pageNumber: Int
    public let text: String

    public init(pageNumber: Int, text: String) {
        self.pageNumber = pageNumber
        self.text = text
    }
}

public struct AgentPDFContext: Equatable, Sendable {
    public let title: String
    public let pageCount: Int
    public let currentPageNumber: Int
    public let currentPageText: String
    public let nearbyPageExcerpts: [AgentPDFPageExcerpt]
    public let outlineItems: [String]
    public let documentPageExcerpts: [AgentPDFPageExcerpt]

    public init(
        title: String,
        pageCount: Int,
        currentPageNumber: Int,
        currentPageText: String,
        nearbyPageExcerpts: [AgentPDFPageExcerpt],
        outlineItems: [String],
        documentPageExcerpts: [AgentPDFPageExcerpt] = []
    ) {
        self.title = title
        self.pageCount = pageCount
        self.currentPageNumber = currentPageNumber
        self.currentPageText = currentPageText
        self.nearbyPageExcerpts = nearbyPageExcerpts
        self.outlineItems = outlineItems
        self.documentPageExcerpts = documentPageExcerpts
    }
}

public enum AgentPromptBuilder {
    private static let currentPageLimit = 3_200
    private static let nearbyPageLimit = 1_200
    private static let documentPageMapLimit = 24
    private static let documentPageMapExcerptLimit = 650
    private static let outlineLimit = 12

    public static func build(
        userPrompt: String,
        transcript: String,
        pdfContext: AgentPDFContext?
    ) -> String {
        """
        You are ReadArc, an agent-powered macOS PDF reader. Help the user read, summarize, search, and analyze the current PDF.

        Response rules:
        - Answer the latest user message directly.
        - Do not introduce yourself unless the user asks who you are.
        - Do not say you already analyzed, just analyzed, or previously covered the PDF unless the user explicitly asks for a recap.
        - Use prior chat only for necessary context; do not repeat earlier answers.
        - Keep the response in the same language as the latest user message.
        - When citing PDF evidence, include page numbers when available.
        - Use only the PDF text context supplied below; do not access local files or folders.

        \(documentContext(pdfContext))

        The app-visible chat transcript below is context only. Use it to avoid contradictions, but do not summarize or replay it unless requested.

        \(transcript)
        """
    }

    private static func documentContext(_ context: AgentPDFContext?) -> String {
        guard let context else {
            return "No PDF is currently open."
        }

        var sections: [String] = [
            "PDF: \(context.title)",
            "Pages: \(context.pageCount), current page: \(context.currentPageNumber)"
        ]

        if !context.outlineItems.isEmpty {
            sections.append(
                """
                Outline:
                \(context.outlineItems.prefix(outlineLimit).map { "- \($0)" }.joined(separator: "\n"))
                """
            )
        }

        let currentPageText = bounded(context.currentPageText, limit: currentPageLimit)
        if !currentPageText.isEmpty {
            sections.append(
                """
                Current page \(context.currentPageNumber) text:
                \(currentPageText)
                """
            )
        }

        let nearby = context.nearbyPageExcerpts
            .map { excerpt -> String in
                let text = bounded(excerpt.text, limit: nearbyPageLimit)
                guard !text.isEmpty else { return "" }
                return """
                Page \(excerpt.pageNumber) excerpt:
                \(text)
                """
            }
            .filter { !$0.isEmpty }

        if !nearby.isEmpty {
            sections.append(
                """
                Nearby page context:
                \(nearby.joined(separator: "\n\n"))
                """
            )
        }

        let pageMap = context.documentPageExcerpts
            .prefix(documentPageMapLimit)
            .map { excerpt -> String in
                let text = bounded(excerpt.text, limit: documentPageMapExcerptLimit)
                guard !text.isEmpty else { return "" }
                return "Page \(excerpt.pageNumber): \(text)"
            }
            .filter { !$0.isEmpty }

        if !pageMap.isEmpty {
            sections.append(
                """
                Document page map:
                \(pageMap.joined(separator: "\n"))
                """
            )
        }

        return sections.joined(separator: "\n\n")
    }

    private static func bounded(_ text: String, limit: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > limit else {
            return normalized
        }

        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

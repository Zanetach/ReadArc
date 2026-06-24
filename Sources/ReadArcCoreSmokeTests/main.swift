import Darwin
import Foundation
import ReadArcCore

@main
struct ReadArcCoreSmokeTests {
    static func main() async {
        let failures = await MainActor.run {
            runTests()
        }

        guard failures.isEmpty else {
            for failure in failures {
                fputs("FAIL: \(failure)\n", stderr)
            }
            exit(1)
        }

        print("ReadArcCoreSmokeTests passed")
    }

    @MainActor
    private static func runTests() -> [String] {
        var failures: [String] = []
        failures.append(contentsOf: testAddMovesExistingDocumentToFrontWithoutDuplicates())
        failures.append(contentsOf: testLimitKeepsMostRecentDocuments())
        failures.append(contentsOf: testAgentPromptIncludesBoundedCurrentPageContext())
        failures.append(contentsOf: testAgentPromptOmitsEmptyDocumentContext())
        failures.append(contentsOf: testAgentPromptDiscouragesRepeatedRecaps())
        failures.append(contentsOf: testElapsedDurationUsesSecondsForShortReplies())
        failures.append(contentsOf: testElapsedDurationUsesMinutesForLongReplies())
        failures.append(contentsOf: testAgentPromptIncludesDocumentPageMap())
        failures.append(contentsOf: testCodexJSONParserExtractsAgentMessageText())
        failures.append(contentsOf: testCodexJSONParserIgnoresNonJSONWarnings())
        failures.append(contentsOf: testClaudeJSONParserExtractsStreamDelta())
        failures.append(contentsOf: testClaudeJSONParserIgnoresAssistantSnapshots())
        failures.append(contentsOf: testClaudeJSONParserExtractsFinalResult())
        failures.append(contentsOf: testClaudeJSONParserIgnoresToolUse())
        failures.append(contentsOf: testSearchTextLocatorReturnsUTF16Range())
        return failures
    }

    @MainActor
    private static func testAddMovesExistingDocumentToFrontWithoutDuplicates() -> [String] {
        let defaults = makeDefaults()
        let store = RecentDocumentsStore(defaults: defaults, storageKey: "recent-test")
        let first = URL(fileURLWithPath: "/tmp/first.pdf")
        let second = URL(fileURLWithPath: "/tmp/second.pdf")

        store.add(url: first)
        store.add(url: second)
        store.add(url: first)

        return store.documents.map(\.url) == [first, second]
            ? []
            : ["expected duplicate recent document to move to front without duplication"]
    }

    @MainActor
    private static func testLimitKeepsMostRecentDocuments() -> [String] {
        let defaults = makeDefaults()
        let store = RecentDocumentsStore(defaults: defaults, storageKey: "recent-limit-test", limit: 2)
        let first = URL(fileURLWithPath: "/tmp/first.pdf")
        let second = URL(fileURLWithPath: "/tmp/second.pdf")
        let third = URL(fileURLWithPath: "/tmp/third.pdf")

        store.add(url: first)
        store.add(url: second)
        store.add(url: third)

        return store.documents.map(\.url) == [third, second]
            ? []
            : ["expected recent document limit to keep only the newest documents"]
    }

    private static func testAgentPromptIncludesBoundedCurrentPageContext() -> [String] {
        let longText = String(repeating: "capacity planning ", count: 300)
        let prompt = AgentPromptBuilder.build(
            userPrompt: "Summarize this page.",
            transcript: "User: Summarize this page.",
            pdfContext: AgentPDFContext(
                title: "ReadArc Spec.pdf",
                location: "/tmp",
                pageCount: 12,
                currentPageNumber: 4,
                currentPageText: longText,
                nearbyPageExcerpts: [
                    AgentPDFPageExcerpt(pageNumber: 3, text: "previous page context"),
                    AgentPDFPageExcerpt(pageNumber: 5, text: "next page context")
                ],
                outlineItems: ["Intro", "Capacity planning"]
            )
        )

        var failures: [String] = []
        if !prompt.contains("Current page 4 text") {
            failures.append("expected prompt to include current page context label")
        }
        if !prompt.contains("previous page context") || !prompt.contains("next page context") {
            failures.append("expected prompt to include nearby page excerpts")
        }
        if !prompt.contains("Capacity planning") {
            failures.append("expected prompt to include outline context")
        }
        if prompt.contains(String(repeating: "capacity planning ", count: 260)) {
            failures.append("expected long page text to be bounded before sending to the agent")
        }
        return failures
    }

    private static func testAgentPromptOmitsEmptyDocumentContext() -> [String] {
        let prompt = AgentPromptBuilder.build(
            userPrompt: "What is this?",
            transcript: "User: What is this?",
            pdfContext: nil
        )

        return prompt.contains("No PDF is currently open.")
            ? []
            : ["expected prompt without a document to state that no PDF is open"]
    }

    private static func testAgentPromptDiscouragesRepeatedRecaps() -> [String] {
        let prompt = AgentPromptBuilder.build(
            userPrompt: "继续",
            transcript: "Claude Code: 这份文档讲的是 onboarding 流程。\n\nUser: 继续",
            pdfContext: nil
        )

        var failures: [String] = []
        if !prompt.contains("Do not say you already analyzed") {
            failures.append("expected prompt to prevent repeated Claude Code recap phrasing")
        }
        if !prompt.contains("context only") {
            failures.append("expected transcript to be treated as context only")
        }
        if !prompt.contains("same language as the latest user message") {
            failures.append("expected prompt to preserve user language")
        }
        return failures
    }

    private static func testElapsedDurationUsesSecondsForShortReplies() -> [String] {
        let start = Date(timeIntervalSince1970: 10)
        let end = Date(timeIntervalSince1970: 11.42)
        let label = ChatMessageMetadataFormatter.elapsedLabel(startedAt: start, completedAt: end)

        return label == "1.4s"
            ? []
            : ["expected short elapsed duration to use one decimal second, got \(label ?? "nil")"]
    }

    private static func testElapsedDurationUsesMinutesForLongReplies() -> [String] {
        let start = Date(timeIntervalSince1970: 10)
        let end = Date(timeIntervalSince1970: 76)
        let label = ChatMessageMetadataFormatter.elapsedLabel(startedAt: start, completedAt: end)

        return label == "1m 06s"
            ? []
            : ["expected long elapsed duration to use minutes and seconds, got \(label ?? "nil")"]
    }

    private static func testAgentPromptIncludesDocumentPageMap() -> [String] {
        let prompt = AgentPromptBuilder.build(
            userPrompt: "Analyze the whole document.",
            transcript: "User: Analyze the whole document.",
            pdfContext: AgentPDFContext(
                title: "ReadArc Spec.pdf",
                location: "/tmp",
                pageCount: 3,
                currentPageNumber: 1,
                currentPageText: "current page",
                nearbyPageExcerpts: [],
                outlineItems: [],
                documentPageExcerpts: [
                    AgentPDFPageExcerpt(pageNumber: 1, text: "first page overview"),
                    AgentPDFPageExcerpt(pageNumber: 2, text: "second page overview")
                ]
            )
        )

        return prompt.contains("Document page map")
            && prompt.contains("Page 1: first page overview")
            && prompt.contains("Page 2: second page overview")
            ? []
            : ["expected prompt to include bounded document page map from cached page text"]
    }

    private static func testCodexJSONParserExtractsAgentMessageText() -> [String] {
        let line = #"{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"analysis result"}}"#
        let text = CodexJSONEventParser.visibleText(fromLine: line)

        return text == "analysis result"
            ? []
            : ["expected Codex JSON parser to extract completed agent message text"]
    }

    private static func testCodexJSONParserIgnoresNonJSONWarnings() -> [String] {
        let text = CodexJSONEventParser.visibleText(fromLine: "WARN codex_rollout something")

        return text == nil
            ? []
            : ["expected Codex JSON parser to ignore non-JSON warning lines"]
    }

    private static func testClaudeJSONParserExtractsStreamDelta() -> [String] {
        let line = #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"partial claude text"}}}"#
        let event = ClaudeJSONEventParser.visibleEvent(fromLine: line)

        return event == .assistantText("partial claude text")
            ? []
            : ["expected Claude JSON parser to extract stream_event text deltas"]
    }

    private static func testClaudeJSONParserIgnoresAssistantSnapshots() -> [String] {
        let line = #"{"type":"assistant","message":{"type":"message","role":"assistant","content":[{"type":"text","text":"claude analysis"}]}}"#
        let event = ClaudeJSONEventParser.visibleEvent(fromLine: line)

        return event == nil
            ? []
            : ["expected Claude JSON parser to ignore assistant snapshots that duplicate text deltas"]
    }

    private static func testClaudeJSONParserExtractsFinalResult() -> [String] {
        let line = #"{"type":"result","subtype":"success","result":"final claude answer"}"#
        let event = ClaudeJSONEventParser.visibleEvent(fromLine: line)

        return event == .finalResult("final claude answer")
            ? []
            : ["expected Claude JSON parser to extract final result fallback"]
    }

    private static func testClaudeJSONParserIgnoresToolUse() -> [String] {
        let line = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/a.pdf"}}]}}"#
        let event = ClaudeJSONEventParser.visibleEvent(fromLine: line)

        return event == nil
            ? []
            : ["expected Claude JSON parser to ignore non-text tool events"]
    }

    private static func testSearchTextLocatorReturnsUTF16Range() -> [String] {
        let text = "Intro café planning"
        guard let match = SearchTextLocator.firstMatch(in: text, query: "planning") else {
            return ["expected search locator to find query"]
        }

        let expectedLocation = (text as NSString).range(of: "planning").location
        var failures: [String] = []
        if match.location != expectedLocation {
            failures.append("expected match location \(expectedLocation), got \(match.location)")
        }
        if match.length != "planning".utf16.count {
            failures.append("expected match length to use UTF-16 length")
        }
        return failures
    }

    private static func makeDefaults() -> UserDefaults {
        let suiteName = "ReadArcCoreSmokeTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

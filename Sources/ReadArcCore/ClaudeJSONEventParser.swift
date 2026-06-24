import Foundation

public enum ClaudeJSONVisibleEvent: Equatable, Sendable {
    case assistantText(String)
    case finalResult(String)
}

public enum ClaudeJSONEventParser {
    public static func visibleEvent(fromLine line: String) -> ClaudeJSONVisibleEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let text = assistantText(from: root) {
            return .assistantText(text)
        }

        if root["type"] as? String == "result",
           let result = root["result"] as? String {
            return nonEmpty(result).map(ClaudeJSONVisibleEvent.finalResult)
        }

        return nil
    }

    private static func assistantText(from root: [String: Any]) -> String? {
        if root["type"] as? String == "stream_event",
           let event = root["event"] as? [String: Any],
           let delta = event["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return nonEmpty(text)
        }

        if let delta = root["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return nonEmpty(text)
        }

        if let text = root["delta"] as? String {
            return nonEmpty(text)
        }

        // Claude Code can emit full assistant message snapshots when
        // --include-partial-messages is enabled. Those snapshots duplicate the
        // content_block_delta stream, so visible output only consumes deltas and
        // uses the final result event as a fallback.
        return nil
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }
}

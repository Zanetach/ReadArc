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

        guard root["type"] as? String == "assistant",
              let message = root["message"] as? [String: Any] else {
            return nil
        }

        if let text = message["content"] as? String {
            return nonEmpty(text)
        }

        guard let content = message["content"] as? [[String: Any]] else {
            return nil
        }

        let text = content
            .compactMap { block -> String? in
                guard block["type"] as? String == "text" else { return nil }
                return block["text"] as? String
            }
            .joined()

        return nonEmpty(text)
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }
}

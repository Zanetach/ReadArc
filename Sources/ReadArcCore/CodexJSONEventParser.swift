import Foundation

public enum CodexJSONEventParser {
    public static func visibleText(fromLine line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"),
              let data = trimmed.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let item = root["item"] as? [String: Any],
           item["type"] as? String == "agent_message",
           let text = item["text"] as? String {
            return nonEmpty(text)
        }

        if root["type"] as? String == "agent_message",
           let text = root["text"] as? String {
            return nonEmpty(text)
        }

        if let delta = root["delta"] as? String {
            return nonEmpty(delta)
        }

        return nil
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : text
    }
}

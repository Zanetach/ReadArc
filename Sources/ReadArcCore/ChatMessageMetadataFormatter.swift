import Foundation

public enum ChatMessageMetadataFormatter {
    public static func elapsedLabel(startedAt: Date, completedAt: Date?) -> String? {
        guard let completedAt else { return nil }
        let elapsed = max(0, completedAt.timeIntervalSince(startedAt))

        if elapsed < 60 {
            return String(format: "%.1fs", elapsed)
        }

        let totalSeconds = Int(elapsed.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%dm %02ds", minutes, seconds)
    }
}

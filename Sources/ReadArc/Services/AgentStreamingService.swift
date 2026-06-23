import Foundation
import ReadArcCore

enum AgentStreamingService {
    static func availability(for agent: ChatAgentProvider) -> AgentAvailability {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", agent.commandName]
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = environment()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .unavailable
        }

        return process.terminationStatus == 0 ? .available : .unavailable
    }

    static func stream(prompt: String, agent: ChatAgentProvider, workingDirectory: URL?) -> AsyncThrowingStream<String, Error> {
        switch agent {
        case .codexCLI:
            return codexJSONStream(prompt: prompt, workingDirectory: workingDirectory)
        case .claudeCode:
            return claudeJSONStream(prompt: prompt, workingDirectory: workingDirectory)
        }
    }

    private static func codexJSONStream(prompt: String, workingDirectory: URL?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let stdout = Pipe()
            let stdin = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                "codex",
                "exec",
                "--json",
                "--skip-git-repo-check",
                "--color",
                "never",
                "-"
            ]
            process.currentDirectoryURL = workingDirectory
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr
            process.environment = environment()

            let buffer = JSONLineBuffer()
            drain(stderr)

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                for line in buffer.append(text) {
                    if let visibleText = CodexJSONEventParser.visibleText(fromLine: line) {
                        continuation.yield(visibleText)
                    }
                }
            }

            process.terminationHandler = { process in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: AgentStreamingError.processFailed(process.terminationStatus))
                }
            }

            continuation.onTermination = { _ in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
                writePrompt(prompt, to: stdin)
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    private static func claudeJSONStream(prompt: String, workingDirectory: URL?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let stdout = Pipe()
            let stdin = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                "claude",
                "-p",
                "--verbose",
                "--output-format",
                "stream-json",
                "--include-partial-messages"
            ]
            process.currentDirectoryURL = workingDirectory
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr
            process.environment = environment()

            let buffer = JSONLineBuffer()
            let coalescer = ClaudeStreamCoalescer()
            drain(stderr)

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                for line in buffer.append(text) {
                    guard let event = ClaudeJSONEventParser.visibleEvent(fromLine: line),
                          let visibleText = coalescer.visibleText(for: event) else {
                        continue
                    }
                    continuation.yield(visibleText)
                }
            }

            process.terminationHandler = { process in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: AgentStreamingError.processFailed(process.terminationStatus))
                }
            }

            continuation.onTermination = { _ in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
                writePrompt(prompt, to: stdin)
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    private static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? NSHomeDirectory()
        let extraPaths = [
            "\(home)/.local/bin",
            "\(home)/.hermes/node/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        return env
    }

    private static func writePrompt(_ prompt: String, to pipe: Pipe) {
        let data = Data(prompt.utf8)
        pipe.fileHandleForWriting.write(data)
        try? pipe.fileHandleForWriting.close()
    }

    private static func drain(_ pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
    }
}

private final class JSONLineBuffer: @unchecked Sendable {
    private static let maxPendingCharacters = 1_000_000
    private var pending = ""

    func append(_ text: String) -> [String] {
        pending += text
        if pending.count > Self.maxPendingCharacters {
            pending.removeAll(keepingCapacity: true)
            return []
        }
        let parts = pending.split(separator: "\n", omittingEmptySubsequences: false)
        guard let last = parts.last else { return [] }
        pending = String(last)
        return parts.dropLast().map(String.init)
    }
}

private final class ClaudeStreamCoalescer: @unchecked Sendable {
    private var assistantText = ""

    func visibleText(for event: ClaudeJSONVisibleEvent) -> String? {
        switch event {
        case .assistantText(let text):
            let output: String
            if text.hasPrefix(assistantText) {
                output = String(text.dropFirst(assistantText.count))
                assistantText = text
            } else {
                output = text
                assistantText += text
            }
            return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : output

        case .finalResult(let text):
            return assistantText.isEmpty ? text : nil
        }
    }
}

enum AgentAvailability: Equatable {
    case checking
    case available
    case unavailable
}

enum AgentStreamingError: LocalizedError {
    case processFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .processFailed(let status):
            return "Agent process exited with status \(status)."
        }
    }
}

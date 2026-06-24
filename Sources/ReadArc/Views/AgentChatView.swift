import AppKit
import ReadArcCore
import SwiftUI

struct AgentChatView: View {
    @ObservedObject var model: ReaderModel
    let modeSwitcher: AnyView
    @State private var draftMessage = ""
    @State private var activeTask: Task<Void, Never>?
    @State private var availability: [ChatAgentProvider: AgentAvailability] = [:]
    @Environment(\.appLanguage) private var language
    private let streamFlushInterval: TimeInterval = 0.05
    private let streamFlushCharacterLimit = 640
    private let streamedMessageCharacterLimit = 80_000
    private let transcriptMessageLimit = 14
    private let transcriptMessageCharacterLimit = 2_400

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

            agentSwitcher

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    contextPanel

                    if model.chatMessages.isEmpty {
                        MessageBubble(
                            message: ChatMessage(
                                role: .assistant,
                                text: language.text("chat.initial"),
                                agent: model.selectedChatAgent,
                                isStreaming: false
                            )
                        )
                    }

                    ForEach(model.chatMessages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding(14)
            }

            composer
        }
        .onDisappear {
            stopStreaming()
        }
        .task {
            await refreshAvailability()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            modeSwitcher

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NativeProTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(NativeProTheme.selection.opacity(0.86), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(language.text("chat.title"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NativeProTheme.ink)

                    Text(language.text("chat.subtitle"))
                        .font(.system(size: 12))
                        .foregroundStyle(NativeProTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var agentSwitcher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Agent", selection: $model.selectedChatAgent) {
                ForEach(ChatAgentProvider.allCases) { agent in
                    Label(agent.pickerTitle, systemImage: agent.systemImage)
                        .tag(agent)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 8) {
                AgentStatusPill(
                    agent: model.selectedChatAgent,
                    availability: availability[model.selectedChatAgent] ?? .checking,
                    language: language
                )
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Image(systemName: model.hasDocument ? "doc.richtext.fill" : "doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text("PDF")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(model.hasDocument ? NativeProTheme.success : NativeProTheme.muted)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(model.hasDocument ? NativeProTheme.selection.opacity(0.72) : NativeProTheme.panel.opacity(0.52), in: Capsule())
            }
        }
        .padding(12)
        .background(NativeProTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(NativeProTheme.separator.opacity(1.2))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var contextPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language.text("chat.context").uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NativeProTheme.muted)

                Spacer(minLength: 0)

                Text(model.hasDocument ? language.text("chat.attached").lowercased() : language.text("chat.empty").lowercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(model.hasDocument ? NativeProTheme.success : NativeProTheme.muted)
            }

            Text(model.hasDocument ? model.documentTitle : language.text("chat.noPDFContext"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NativeProTheme.ink)
                .lineLimit(2)

            if model.hasDocument {
                Text(String(format: language.text("chat.pages"), model.pageCount, model.pageIndex + 1))
                    .font(.system(size: 12))
                    .foregroundStyle(NativeProTheme.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeProTheme.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(NativeProTheme.separator)
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                composerInput
                sendButton
            }
        }
        .padding(14)
        .background(NativeProTheme.inspector)
    }

    private var composerInput: some View {
        TextField(String(format: language.text("chat.placeholder"), model.selectedChatAgent.title), text: $draftMessage, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .lineLimit(2...6)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(minHeight: 48, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(NativeProTheme.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(NativeProTheme.separator, lineWidth: 1)
            }
    }

    private var sendButton: some View {
        Button {
            if isStreaming {
                stopStreaming()
            } else {
                sendDraft()
            }
        } label: {
            Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 42, height: 42)
                .background(sendButtonBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(sendButtonForeground)
        }
        .buttonStyle(.plain)
        .disabled(!canSend && !isStreaming)
        .help(isStreaming ? "Stop streaming" : "Send to \(model.selectedChatAgent.pickerTitle)")
    }

    private var sendButtonBackground: Color {
        canSend || isStreaming ? NativeProTheme.accent : NativeProTheme.tile
    }

    private var sendButtonForeground: Color {
        canSend || isStreaming ? .white : NativeProTheme.muted
    }

    private var canSend: Bool {
        !isStreaming
            && selectedAgentAvailable
            && !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isStreaming: Bool {
        activeTask != nil
    }

    private var selectedAgentAvailable: Bool {
        availability[model.selectedChatAgent] == .available
    }

    private func sendDraft() {
        let prompt = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, activeTask == nil else { return }
        guard selectedAgentAvailable else {
            model.chatMessages.append(
                ChatMessage(
                    role: .assistant,
                    text: String(format: language.text("chat.agentUnavailable"), model.selectedChatAgent.commandName),
                    agent: model.selectedChatAgent,
                    isStreaming: false
                )
            )
            model.pruneChatHistory()
            return
        }

        let agent = model.selectedChatAgent
        let agentPrompt = buildAgentPrompt(userPrompt: prompt)
        let responseMessage = ChatMessage(role: .assistant, text: "", agent: agent, isStreaming: true)
        let responseID = responseMessage.id
        model.chatMessages.append(ChatMessage(role: .user, text: prompt, agent: nil, isStreaming: false))
        model.chatMessages.append(responseMessage)
        model.pruneChatHistory()
        draftMessage = ""

        activeTask = Task {
            do {
                let stream = AgentStreamingService.stream(
                    prompt: agentPrompt,
                    agent: agent,
                    workingDirectory: nil
                )

                var pendingChunk = ""
                var lastFlush = Date()
                for try await chunk in stream {
                    pendingChunk += chunk
                    let shouldFlush = pendingChunk.count >= streamFlushCharacterLimit
                        || Date().timeIntervalSince(lastFlush) >= streamFlushInterval

                    if shouldFlush {
                        let output = pendingChunk
                        pendingChunk = ""
                        lastFlush = Date()
                        await MainActor.run {
                            appendStreamChunk(output, to: responseID)
                        }
                    }
                }

                await MainActor.run {
                    if !pendingChunk.isEmpty {
                        appendStreamChunk(pendingChunk, to: responseID)
                    }
                    finishStreaming(responseID)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    appendStreamChunk("\n\(language.text("chat.agentRunFailed"))", to: responseID)
                    finishStreaming(responseID)
                }
            }
        }
    }

    private func stopStreaming() {
        activeTask?.cancel()
        activeTask = nil
        if let index = model.chatMessages.lastIndex(where: { $0.isStreaming }) {
            model.chatMessages[index].isStreaming = false
            model.chatMessages[index].completedAt = Date()
        }
    }

    private func buildAgentPrompt(userPrompt: String) -> String {
        let transcript = conversationTranscript(including: userPrompt)
        return AgentPromptBuilder.build(
            userPrompt: userPrompt,
            transcript: transcript,
            pdfContext: model.agentPDFContext()
        )
    }

    private func conversationTranscript(including userPrompt: String) -> String {
        var lines: [String] = []

        for message in model.chatMessages.suffix(transcriptMessageLimit) {
            let text = boundedTranscriptText(message.text)
            guard !text.isEmpty else { continue }
            switch message.role {
            case .user:
                lines.append("User: \(text)")
            case .assistant:
                let agentName = message.agent?.title ?? "Agent"
                lines.append("\(agentName): \(text)")
            }
        }

        lines.append("User: \(userPrompt)")
        return lines.joined(separator: "\n\n")
    }

    private func boundedTranscriptText(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > transcriptMessageCharacterLimit else {
            return normalized
        }

        let end = normalized.index(normalized.startIndex, offsetBy: transcriptMessageCharacterLimit)
        return String(normalized[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func appendStreamChunk(_ chunk: String, to id: UUID) {
        guard let index = model.chatMessages.firstIndex(where: { $0.id == id }) else { return }
        let currentText = model.chatMessages[index].text
        guard currentText.count < streamedMessageCharacterLimit else { return }

        let remaining = streamedMessageCharacterLimit - currentText.count
        if chunk.count <= remaining {
            model.chatMessages[index].text += chunk
        } else {
            let end = chunk.index(chunk.startIndex, offsetBy: remaining)
            model.chatMessages[index].text += String(chunk[..<end])
            model.chatMessages[index].text += "\n\n\(language.text("chat.outputTruncated"))"
        }
    }

    private func finishStreaming(_ id: UUID) {
        if let index = model.chatMessages.firstIndex(where: { $0.id == id }) {
            if model.chatMessages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                model.chatMessages[index].text = "No output from \(model.chatMessages[index].agent?.title ?? "agent")."
            }
            model.chatMessages[index].isStreaming = false
            model.chatMessages[index].completedAt = Date()
        }
        model.pruneChatHistory()
        activeTask = nil
    }

    @MainActor
    private func refreshAvailability() async {
        availability = Dictionary(uniqueKeysWithValues: ChatAgentProvider.allCases.map { ($0, .checking) })

        for agent in ChatAgentProvider.allCases {
            let result = await Task.detached(priority: .utility) {
                AgentStreamingService.availability(for: agent)
            }.value
            availability[agent] = result
        }
    }
}

private struct AgentStatusPill: View {
    let agent: ChatAgentProvider
    let availability: AgentAvailability
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 11, weight: .medium))

            Text(statusText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(NativeProTheme.tile.opacity(0.74), in: Capsule())
        .help("\(agent.title): \(statusText)")
    }

    private var statusIcon: String {
        switch availability {
        case .checking:
            return "clock"
        case .available:
            return "checkmark.circle.fill"
        case .unavailable:
            return "xmark.circle.fill"
        }
    }

    private var statusText: String {
        switch availability {
        case .checking:
            return language.text("chat.status.checking")
        case .available:
            return language.text("chat.status.available")
        case .unavailable:
            return language.text("chat.status.unavailable")
        }
    }

    private var statusColor: Color {
        switch availability {
        case .checking:
            return NativeProTheme.muted
        case .available:
            return NativeProTheme.success
        case .unavailable:
            return NativeProTheme.muted
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    @State private var didCopy = false
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 34)
            }

            if message.role == .assistant {
                ChatAvatar(role: message.role)
            }

            VStack(alignment: .leading, spacing: 5) {
                header

                if message.isStreaming && message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TypingIndicator()
                        .padding(.top, 1)
                } else {
                    Text(messageText)
                        .font(.system(size: 13))
                        .foregroundStyle(message.role == .user ? .white : NativeProTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                metadata
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(message.role == .assistant ? NativeProTheme.separator : .clear, lineWidth: 1)
            }

            if message.role == .assistant {
                Spacer(minLength: 34)
            }

            if message.role == .user {
                ChatAvatar(role: message.role)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let agent = message.agent {
                Text(agent.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NativeProTheme.muted)
            }

            if canCopy {
                Button {
                    copyMessage()
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .foregroundStyle(didCopy ? NativeProTheme.success : NativeProTheme.muted)
                .help(didCopy ? "Copied" : "Copy message")
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 6) {
            Text(timeLabel)

            if let elapsedLabel {
                Text("·")
                Text(elapsedLabel)
            } else if message.isStreaming {
                Text("·")
                Text(language.text("chat.status.running"))
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(NativeProTheme.muted.opacity(0.78))
    }

    private var messageText: String {
        if message.isStreaming {
            return message.text + " ▌"
        }
        return message.text
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user:
            return NativeProTheme.accent
        case .assistant:
            return NativeProTheme.panel.opacity(0.82)
        }
    }

    private var timeLabel: String {
        message.createdAt.formatted(date: .omitted, time: .shortened)
    }

    private var elapsedLabel: String? {
        ChatMessageMetadataFormatter.elapsedLabel(startedAt: message.createdAt, completedAt: message.completedAt)
    }

    private var canCopy: Bool {
        !copyText.isEmpty
    }

    private var copyText: String {
        message.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func copyMessage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copyText, forType: .string)
        didCopy = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopy = false
        }
    }
}

private struct TypingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(NativeProTheme.muted.opacity(isAnimating ? 0.90 : 0.38))
                    .frame(width: 5, height: 5)
                    .scaleEffect(isAnimating ? 1.0 : 0.58)
                    .animation(
                        .easeInOut(duration: 0.52)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 34, height: 16, alignment: .leading)
        .accessibilityLabel("ReadArc is thinking")
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

private struct ChatAvatar: View {
    let role: ChatMessage.Role

    var body: some View {
        Image(systemName: role == .user ? "person.crop.circle.fill" : "cpu.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(role == .user ? NativeProTheme.accent : NativeProTheme.success)
            .frame(width: 30, height: 30)
            .background(NativeProTheme.panel.opacity(0.82), in: Circle())
            .overlay {
                Circle()
                    .stroke(NativeProTheme.separator, lineWidth: 1)
            }
    }
}

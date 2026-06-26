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
        GeometryReader { proxy in
            let metrics = ChatPanelMetrics(size: proxy.size)

            VStack(spacing: 0) {
                chatSurface(metrics: metrics)
            }
        }
        .background(Color.clear)
        .onDisappear {
            stopStreaming()
        }
        .task {
            await refreshAvailability()
        }
    }

    private func chatSurface(metrics: ChatPanelMetrics) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header(metrics: metrics)

                ScrollView {
                    VStack(alignment: .leading, spacing: metrics.messageSpacing) {
                        if model.hasDocument {
                            quickActionsPanel(metrics: metrics)
                        }

                        if model.chatMessages.isEmpty {
                            greetingPanel(metrics: metrics)
                        }

                        ForEach(model.chatMessages) { message in
                            MessageBubble(message: message, metrics: metrics)
                        }
                    }
                    .padding(.horizontal, metrics.contentPadding)
                    .padding(.vertical, metrics.contentVerticalPadding)
                }
                .scrollContentBackground(.hidden)

                composer(metrics: metrics)
            }
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous),
                fallbackColor: NativeProTheme.sidebar,
                strokeColor: NativeProTheme.separator.opacity(0.55)
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous))
        }
    }

    private func header(metrics: ChatPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                modeSwitcher
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, metrics.headerHorizontalPadding)
        .padding(.top, metrics.headerTopPadding)
        .padding(.bottom, metrics.headerBottomPadding)
    }

    private var agentSwitcher: some View {
        HStack(alignment: .center, spacing: 10) {
            Picker("Agent", selection: $model.selectedChatAgent) {
                ForEach(ChatAgentProvider.allCases) { agent in
                    Label(agent.pickerTitle, systemImage: agent.systemImage)
                        .tag(agent)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 210)

            Spacer(minLength: 0)

            AgentStatusPill(
                agent: model.selectedChatAgent,
                availability: availability[model.selectedChatAgent] ?? .checking,
                language: language
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: 12, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.42),
            strokeColor: NativeProTheme.separator.opacity(0.48)
        )
    }

    private func quickActionsPanel(metrics: ChatPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.quickActionSpacing) {
            Text(language.text("chat.quickActions"))
                .font(.system(size: metrics.headingFont, weight: .semibold))
                .foregroundStyle(NativeProTheme.ink)

            QuickActionButton(title: language.text("chat.action.summaryPage"), systemImage: "doc.text", metrics: metrics) {
                sendQuickPrompt(language.text("chat.prompt.summaryPage"))
            }

            QuickActionButton(title: language.text("chat.action.keyPoints"), systemImage: "sparkles", metrics: metrics) {
                sendQuickPrompt(language.text("chat.prompt.keyPoints"))
            }

            QuickActionButton(title: language.text("chat.action.mindMap"), systemImage: "square.grid.2x2", metrics: metrics) {
                sendQuickPrompt(language.text("chat.prompt.mindMap"))
            }
        }
        .padding(metrics.panelPadding)
        .readArcGlass(
            in: RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous),
            fallbackColor: NativeProTheme.panel.opacity(0.34),
            strokeColor: NativeProTheme.separator.opacity(0.42)
        )
    }

    private func greetingPanel(metrics: ChatPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.quickActionSpacing) {
            Text(language.text("chat.greeting"))
                .font(.system(size: metrics.headingFont, weight: .semibold))
                .foregroundStyle(NativeProTheme.ink)

            MessageBubble(
                message: ChatMessage(
                    role: .assistant,
                    text: language.text("chat.initial"),
                    agent: model.selectedChatAgent,
                    isStreaming: false
                ),
                metrics: metrics
            )
        }
    }

    private func composer(metrics: ChatPanelMetrics) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: metrics.composerGap) {
                composerInput(metrics: metrics)
                sendButton(metrics: metrics)
            }
        }
        .padding(metrics.contentPadding)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NativeProTheme.separator)
                .frame(height: 1)
        }
    }

    private func composerInput(metrics: ChatPanelMetrics) -> some View {
        TextField(String(format: language.text("chat.placeholder"), model.selectedChatAgent.title), text: $draftMessage, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: metrics.composerFont))
            .lineLimit(2...6)
            .padding(.horizontal, metrics.composerHorizontalPadding)
            .padding(.vertical, metrics.composerVerticalPadding)
            .frame(minHeight: metrics.composerMinHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous),
                fallbackColor: NativeProTheme.panel.opacity(0.88),
                strokeColor: NativeProTheme.separator.opacity(0.76),
                isInteractive: true
            )
    }

    private func sendButton(metrics: ChatPanelMetrics) -> some View {
        Button {
            if isStreaming {
                stopStreaming()
            } else {
                sendDraft()
            }
        } label: {
            Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                .font(.system(size: metrics.sendIconFont, weight: .bold))
                .frame(width: metrics.sendButtonSize, height: metrics.sendButtonSize)
                .readArcGlass(
                    in: RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous),
                    fallbackColor: sendButtonBackground,
                    strokeColor: canSend || isStreaming ? NativeProTheme.accent.opacity(0.22) : NativeProTheme.separator,
                    isInteractive: true,
                    tint: canSend || isStreaming ? NativeProTheme.accent.opacity(0.22) : nil
                )
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

    private func sendQuickPrompt(_ prompt: String) {
        guard activeTask == nil else { return }
        draftMessage = prompt
        sendDraft()
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
            let result = await AgentStreamingService.cachedAvailability(for: agent)
            availability[agent] = result
        }
    }
}

private struct ChatPanelMetrics: Equatable {
    let width: CGFloat
    let height: CGFloat

    init(size: CGSize) {
        self.width = size.width
        self.height = size.height
    }

    private var scale: CGFloat {
        min(max((width - 260) / 160, 0), 1)
    }

    var outerCornerRadius: CGFloat { 16 + scale * 4 }
    var contentPadding: CGFloat { 11 + scale * 5 }
    var contentVerticalPadding: CGFloat { 10 + scale * 4 }
    var headerHorizontalPadding: CGFloat { 12 + scale * 8 }
    var headerTopPadding: CGFloat { 11 + scale * 5 }
    var headerBottomPadding: CGFloat { 6 + scale * 2 }
    var panelPadding: CGFloat { 10 + scale * 2 }
    var panelCornerRadius: CGFloat { 12 + scale * 2 }
    var headingFont: CGFloat { 12 + scale * 1 }
    var bodyFont: CGFloat { 12 + scale * 1 }
    var captionFont: CGFloat { 9.5 + scale * 0.5 }
    var quickActionFont: CGFloat { 11 + scale * 1 }
    var quickActionIconFont: CGFloat { 11 + scale * 1 }
    var quickActionHeight: CGFloat { 29 + scale * 3 }
    var quickActionSpacing: CGFloat { 7 + scale * 2 }
    var messageSpacing: CGFloat { 9 + scale * 3 }
    var messageOuterSpacing: CGFloat { 7 + scale * 1 }
    var messageSideSpacer: CGFloat { width < 320 ? 18 : 30 }
    var answerBlockSpacing: CGFloat { 7 + scale * 2 }
    var answerCardPadding: CGFloat { 9 + scale * 2 }
    var answerCardCornerRadius: CGFloat { 10 + scale * 2 }
    var answerChildSpacing: CGFloat { 5 + scale * 1 }
    var mindMapNodeSpacing: CGFloat { 8 + scale * 2 }
    var mindMapBranchPadding: CGFloat { 9 + scale * 2 }
    var avatarSize: CGFloat { 25 + scale * 5 }
    var avatarIconFont: CGFloat { 12 + scale * 2 }
    var composerGap: CGFloat { 8 + scale * 2 }
    var composerFont: CGFloat { 12.5 + scale * 1 }
    var composerHorizontalPadding: CGFloat { 10 + scale * 2 }
    var composerVerticalPadding: CGFloat { 9 + scale * 2 }
    var composerMinHeight: CGFloat { 42 + scale * 5 }
    var sendButtonSize: CGFloat { 36 + scale * 5 }
    var sendIconFont: CGFloat { 13 + scale * 1 }
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
        .readArcGlass(
            in: Capsule(),
            fallbackColor: NativeProTheme.tile.opacity(0.72),
            strokeColor: NativeProTheme.separator.opacity(0.65),
            tint: availability == .available ? NativeProTheme.accent.opacity(0.06) : nil
        )
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

private struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let metrics: ChatPanelMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: metrics.quickActionIconFont, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(NativeProTheme.muted)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: metrics.quickActionFont, weight: .medium))
                    .foregroundStyle(NativeProTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .frame(height: metrics.quickActionHeight)
            .readArcGlass(
                in: RoundedRectangle(cornerRadius: metrics.panelCornerRadius - 4, style: .continuous),
                fallbackColor: NativeProTheme.panel.opacity(0.48),
                strokeColor: NativeProTheme.separator.opacity(0.48),
                isInteractive: true
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let metrics: ChatPanelMetrics
    @State private var didCopy = false
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(alignment: .top, spacing: metrics.messageOuterSpacing) {
            if message.role == .user {
                Spacer(minLength: metrics.messageSideSpacer)
            }

            if message.role == .assistant {
                ChatAvatar(role: message.role, metrics: metrics)
            }

            VStack(alignment: contentAlignment, spacing: 5) {
                header

                if message.isStreaming && message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TypingIndicator()
                        .padding(.top, 1)
                } else {
                    if message.role == .assistant {
                        AgentFormattedMessageView(text: messageText, metrics: metrics)
                    } else {
                        Text(messageText)
                            .font(.system(size: metrics.bodyFont))
                            .foregroundStyle(NativeProTheme.ink)
                            .multilineTextAlignment(textAlignment)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                metadata
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)

            if message.role == .assistant {
                Spacer(minLength: metrics.messageSideSpacer)
            }

            if message.role == .user {
                ChatAvatar(role: message.role, metrics: metrics)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let agent = message.agent {
                Text(agent.title)
                    .font(.system(size: metrics.captionFont, weight: .semibold))
                    .foregroundStyle(NativeProTheme.muted)
            }

            if canCopy {
                Button {
                    copyMessage()
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: metrics.captionFont, weight: .semibold))
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
        .font(.system(size: metrics.captionFont, weight: .medium, design: .monospaced))
        .foregroundStyle(NativeProTheme.muted.opacity(0.78))
    }

    private var messageText: String {
        if message.isStreaming {
            return message.text + " ▌"
        }
        return message.text
    }

    private var contentAlignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var textAlignment: TextAlignment {
        message.role == .user ? .trailing : .leading
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

private struct AgentFormattedMessageView: View {
    let text: String
    let metrics: ChatPanelMetrics

    private var blocks: [AgentAnswerBlock] {
        AgentAnswerParser.blocks(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.answerBlockSpacing) {
            ForEach(blocks) { block in
                switch block.kind {
                case .paragraph(let text):
                    AgentParagraphText(text: text, metrics: metrics)
                case .item(let title, let body, let children, let pageReference):
                    AgentAnswerCard(
                        sequence: block.id + 1,
                        title: title,
                        content: body,
                        children: children,
                        pageReference: pageReference,
                        metrics: metrics
                    )
                case .mindMap(let mindMap):
                    AgentMindMapView(mindMap: mindMap, metrics: metrics)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AgentMindMapView: View {
    let mindMap: AgentMindMap
    let metrics: ChatPanelMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.mindMapNodeSpacing) {
            rootNode

            VStack(alignment: .leading, spacing: metrics.answerBlockSpacing) {
                ForEach(Array(mindMap.branches.enumerated()), id: \.element.id) { item in
                    AgentMindMapBranchView(
                        branch: item.element,
                        branchNumber: item.offset + 1,
                        metrics: metrics
                    )
                }
            }
        }
        .padding(metrics.answerCardPadding + 1)
        .background(
            NativeProTheme.tile.opacity(0.60),
            in: RoundedRectangle(cornerRadius: metrics.answerCardCornerRadius + 2, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: metrics.answerCardCornerRadius + 2, style: .continuous)
                .stroke(NativeProTheme.separator.opacity(0.70), lineWidth: 1)
        }
    }

    private var rootNode: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: metrics.bodyFont, weight: .semibold))
                .foregroundStyle(NativeProTheme.accent)
                .frame(width: 20, height: 20)
                .background(NativeProTheme.selection.opacity(0.70), in: Circle())

            InlineMarkdownText(
                text: mindMap.root,
                font: .system(size: metrics.bodyFont + 0.5, weight: .semibold),
                color: NativeProTheme.ink
            )
        }
        .padding(.horizontal, metrics.mindMapBranchPadding)
        .padding(.vertical, metrics.mindMapBranchPadding - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            NativeProTheme.panel.opacity(0.74),
            in: RoundedRectangle(cornerRadius: metrics.answerCardCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: metrics.answerCardCornerRadius, style: .continuous)
                .stroke(NativeProTheme.accent.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct AgentMindMapBranchView: View {
    let branch: AgentMindMapBranch
    let branchNumber: Int
    let metrics: ChatPanelMetrics

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 0) {
                Text("\(branchNumber)")
                    .font(.system(size: metrics.captionFont, weight: .bold, design: .rounded))
                    .foregroundStyle(NativeProTheme.accent)
                    .frame(width: 20, height: 20)
                    .background(NativeProTheme.selection.opacity(0.72), in: Circle())

                Rectangle()
                    .fill(NativeProTheme.accent.opacity(0.22))
                    .frame(width: 1, height: connectorHeight)
                    .padding(.vertical, 4)
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: metrics.answerChildSpacing + 2) {
                InlineMarkdownText(
                    text: branch.title,
                    font: .system(size: metrics.bodyFont, weight: .semibold),
                    color: NativeProTheme.ink
                )

                if !branch.children.isEmpty {
                    VStack(alignment: .leading, spacing: metrics.answerChildSpacing) {
                        ForEach(Array(branch.children.enumerated()), id: \.offset) { item in
                            AgentMindMapLeafView(text: item.element, metrics: metrics)
                        }
                    }
                    .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(metrics.mindMapBranchPadding)
        .background(
            NativeProTheme.panel.opacity(0.58),
            in: RoundedRectangle(cornerRadius: metrics.answerCardCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: metrics.answerCardCornerRadius, style: .continuous)
                .stroke(NativeProTheme.separator.opacity(0.58), lineWidth: 1)
        }
    }

    private var connectorHeight: CGFloat {
        guard !branch.children.isEmpty else {
            return 12
        }
        return min(58, CGFloat(branch.children.count) * (metrics.bodyFont + metrics.answerChildSpacing))
    }
}

private struct AgentMindMapLeafView: View {
    let text: String
    let metrics: ChatPanelMetrics

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(NativeProTheme.success.opacity(0.70))
                .frame(width: 4.5, height: 4.5)
                .offset(y: -1)

            InlineMarkdownText(
                text: text,
                font: .system(size: metrics.bodyFont - 0.5),
                color: NativeProTheme.ink.opacity(0.82)
            )
            .lineSpacing(1.5)
        }
    }
}

private struct AgentAnswerCard: View {
    let sequence: Int
    let title: String?
    let content: String
    let children: [String]
    let pageReference: String?
    let metrics: ChatPanelMetrics

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(sequence)")
                .font(.system(size: metrics.captionFont, weight: .bold, design: .rounded))
                .foregroundStyle(NativeProTheme.accent)
                .frame(width: 21, height: 21)
                .background(NativeProTheme.selection.opacity(0.76), in: Circle())
                .overlay {
                    Circle().stroke(NativeProTheme.accent.opacity(0.18), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 5) {
                if title != nil || pageReference != nil {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let title {
                            InlineMarkdownText(
                                text: title,
                                font: .system(size: metrics.bodyFont, weight: .semibold),
                                color: NativeProTheme.ink
                            )
                        }

                        Spacer(minLength: 0)

                        if let pageReference {
                            Text(pageReference)
                                .font(.system(size: metrics.captionFont, weight: .semibold))
                                .foregroundStyle(NativeProTheme.accent)
                                .padding(.horizontal, 6)
                                .frame(height: 19)
                                .background(NativeProTheme.selection.opacity(0.74), in: Capsule())
                        }
                    }
                }

                if !content.isEmpty {
                    InlineMarkdownText(
                        text: content,
                        font: .system(size: metrics.bodyFont),
                        color: NativeProTheme.ink.opacity(0.88)
                    )
                    .lineSpacing(2)
                }

                if !children.isEmpty {
                    VStack(alignment: .leading, spacing: metrics.answerChildSpacing) {
                        ForEach(Array(children.enumerated()), id: \.offset) { item in
                            AgentChildBullet(text: item.element, metrics: metrics)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(metrics.answerCardPadding)
        .background(NativeProTheme.tile.opacity(0.62), in: RoundedRectangle(cornerRadius: metrics.answerCardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.answerCardCornerRadius, style: .continuous)
                .stroke(NativeProTheme.separator.opacity(0.72), lineWidth: 1)
        }
    }
}

private struct AgentChildBullet: View {
    let text: String
    let metrics: ChatPanelMetrics

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle()
                .fill(NativeProTheme.accent.opacity(0.72))
                .frame(width: 4.5, height: 4.5)
                .offset(y: -1)

            InlineMarkdownText(
                text: text,
                font: .system(size: metrics.bodyFont - 0.5),
                color: NativeProTheme.ink.opacity(0.82)
            )
            .lineSpacing(1.5)
        }
    }
}

private struct AgentParagraphText: View {
    let text: String
    let metrics: ChatPanelMetrics

    var body: some View {
        InlineMarkdownText(
            text: text,
            font: .system(size: metrics.bodyFont),
            color: NativeProTheme.ink
        )
        .lineSpacing(2)
    }
}

private struct InlineMarkdownText: View {
    let text: String
    let font: Font
    let color: Color

    var body: some View {
        renderedText
            .font(font)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var renderedText: Text {
        InlineMarkdownText.runs(from: text).reduce(Text("")) { output, run in
            let segment = run.isStrong ? Text(run.text).fontWeight(.semibold) : Text(run.text)
            return output + segment
        }
    }

    private static func runs(from text: String) -> [(text: String, isStrong: Bool)] {
        var output: [(text: String, isStrong: Bool)] = []
        var cursor = text.startIndex

        while cursor < text.endIndex,
              let start = text[cursor...].range(of: "**") {
            if start.lowerBound > cursor {
                output.append((String(text[cursor..<start.lowerBound]), false))
            }

            let strongStart = start.upperBound
            guard let end = text[strongStart...].range(of: "**") else {
                output.append((String(text[start.lowerBound...]), false))
                return output
            }

            output.append((String(text[strongStart..<end.lowerBound]), true))
            cursor = end.upperBound
        }

        if cursor < text.endIndex {
            output.append((String(text[cursor...]), false))
        }

        return output
    }
}

private struct AgentAnswerBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case paragraph(String)
        case item(title: String?, body: String, children: [String], pageReference: String?)
        case mindMap(AgentMindMap)
    }

    let id: Int
    let kind: Kind
}

private struct AgentMindMap: Equatable {
    let root: String
    let branches: [AgentMindMapBranch]
}

private struct AgentMindMapBranch: Identifiable, Equatable {
    let id: Int
    let title: String
    let children: [String]
}

private enum AgentAnswerParser {
    private struct PendingItem {
        var title: String?
        var body: String
        var children: [String]
        var pageReference: String?
    }

    private enum PendingBlock {
        case paragraph(String)
        case item(PendingItem)
        case mindMap(AgentMindMap)
    }

    static func blocks(from rawText: String) -> [AgentAnswerBlock] {
        let normalized = rawText.replacingOccurrences(of: "\r\n", with: "\n")
        if let mindMap = mindMap(from: normalized) {
            return [AgentAnswerBlock(id: 0, kind: .mindMap(mindMap))]
        }

        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var pendingBlocks: [PendingBlock] = []
        var paragraphLines: [String] = []
        var currentItem: PendingItem?

        func flushParagraph() {
            let paragraph = paragraphLines
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                pendingBlocks.append(.paragraph(paragraph))
            }
            paragraphLines = []
        }

        func flushItem() {
            if let item = currentItem {
                pendingBlocks.append(.item(item))
                currentItem = nil
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                flushParagraph()
                continue
            }

            if let bullet = bulletContent(in: line) {
                if leadingWhitespaceCount(in: line) < 2 {
                    flushParagraph()
                    flushItem()
                    currentItem = item(from: bullet)
                } else if var item = currentItem {
                    item.children.append(cleanInlineMarkdown(bullet))
                    currentItem = item
                } else {
                    flushParagraph()
                    pendingBlocks.append(.item(item(from: bullet)))
                }
            } else if var item = currentItem {
                let addition = cleanInlineMarkdown(trimmed)
                item.body = joinedText(item.body, addition)
                currentItem = item
            } else {
                paragraphLines.append(trimmed)
            }
        }

        flushParagraph()
        flushItem()

        guard !pendingBlocks.isEmpty else {
            let fallback = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? [] : [AgentAnswerBlock(id: 0, kind: .paragraph(fallback))]
        }

        return pendingBlocks.enumerated().map { index, block in
            switch block {
            case .paragraph(let text):
                return AgentAnswerBlock(id: index, kind: .paragraph(cleanInlineMarkdown(text)))
            case .item(let item):
                return AgentAnswerBlock(
                    id: index,
                    kind: .item(
                        title: item.title,
                        body: item.body,
                        children: item.children,
                        pageReference: item.pageReference
                    )
                )
            case .mindMap(let mindMap):
                return AgentAnswerBlock(id: index, kind: .mindMap(mindMap))
            }
        }
    }

    private struct BranchDraft {
        var title: String
        var children: [String]
    }

    private static func mindMap(from rawText: String) -> AgentMindMap? {
        if let mermaid = mermaidMindMap(from: rawText) {
            return mermaid
        }
        return treeMindMap(from: rawText)
    }

    private static func treeMindMap(from rawText: String) -> AgentMindMap? {
        guard rawText.contains("├─") || rawText.contains("└─") else {
            return nil
        }

        let lines = semanticLines(from: rawText)
        guard let firstTreeIndex = lines.firstIndex(where: hasTreeMarker(in:)) else {
            return nil
        }

        let rootCandidates = lines[..<firstTreeIndex]
            .map { cleanMindMapText($0) }
            .filter { !$0.isEmpty && !isMindMapIntro($0) }
        guard let root = rootCandidates.last else {
            return nil
        }

        var drafts: [BranchDraft] = []

        for line in lines[firstTreeIndex...] {
            guard let node = treeNode(in: line) else {
                continue
            }

            if node.level <= 1 {
                drafts.append(BranchDraft(title: node.text, children: []))
            } else if !drafts.isEmpty {
                drafts[drafts.count - 1].children.append(node.text)
            }
        }

        let branches = drafts
            .filter { !$0.title.isEmpty || !$0.children.isEmpty }
            .enumerated()
            .map { index, draft in
                AgentMindMapBranch(id: index, title: draft.title, children: draft.children)
            }

        guard !branches.isEmpty else {
            return nil
        }

        return AgentMindMap(root: root, branches: branches)
    }

    private static func mermaidMindMap(from rawText: String) -> AgentMindMap? {
        let lines = semanticLines(from: rawText)
        guard lines.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("mindmap") == .orderedSame }) else {
            return nil
        }

        let nodes = lines.compactMap { line -> (indent: Int, text: String)? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  trimmed.caseInsensitiveCompare("mindmap") != .orderedSame else {
                return nil
            }

            let text = cleanMermaidMindMapText(trimmed)
            guard !text.isEmpty else {
                return nil
            }

            return (leadingWhitespaceCount(in: line), text)
        }

        guard let rootNode = nodes.first else {
            return nil
        }

        let branchIndent = nodes
            .dropFirst()
            .map(\.indent)
            .filter { $0 > rootNode.indent }
            .min()

        guard let branchIndent else {
            return nil
        }

        var drafts: [BranchDraft] = []
        for node in nodes.dropFirst() {
            if node.indent == branchIndent {
                drafts.append(BranchDraft(title: node.text, children: []))
            } else if node.indent > branchIndent, !drafts.isEmpty {
                drafts[drafts.count - 1].children.append(node.text)
            }
        }

        let branches = drafts.enumerated().map { index, draft in
            AgentMindMapBranch(id: index, title: draft.title, children: draft.children)
        }

        guard !branches.isEmpty else {
            return nil
        }

        return AgentMindMap(root: rootNode.text, branches: branches)
    }

    private static func semanticLines(from rawText: String) -> [String] {
        rawText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && !trimmed.hasPrefix("```")
            }
    }

    private static func hasTreeMarker(in line: String) -> Bool {
        line.contains("├─") || line.contains("└─")
    }

    private static func treeNode(in line: String) -> (level: Int, text: String)? {
        let markerRange = line.range(of: "├─", options: .backwards) ?? line.range(of: "└─", options: .backwards)
        guard let markerRange else {
            return nil
        }

        let prefix = String(line[..<markerRange.lowerBound])
        let text = cleanMindMapText(String(line[markerRange.upperBound...]))
        guard !text.isEmpty else {
            return nil
        }

        let verticalCount = prefix.filter { $0 == "│" }.count
        let spaceCount = prefix.filter { $0 == " " }.count
        let level = max(1, verticalCount + (spaceCount / 3) + 1)
        return (level, text)
    }

    private static func isMindMapIntro(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return line.hasSuffix("思维导图：")
            || line.hasSuffix("思维导图:")
            || lowercased.hasSuffix("mind map:")
            || lowercased.hasSuffix("mindmap:")
    }

    private static func cleanMindMapText(_ text: String) -> String {
        cleanInlineMarkdown(text)
            .replacingOccurrences(of: "```text", with: "")
            .replacingOccurrences(of: "```mermaid", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanMermaidMindMapText(_ text: String) -> String {
        var output = text
            .replacingOccurrences(of: "root", with: "")
            .replacingOccurrences(of: "((", with: "")
            .replacingOccurrences(of: "))", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        output = output.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'"))
        return cleanInlineMarkdown(output)
    }

    private static func item(from content: String) -> PendingItem {
        let (title, remainder) = splitLeadingTitle(in: content)
        let (body, pageReference) = extractPageReference(from: remainder)
        return PendingItem(
            title: title,
            body: cleanInlineMarkdown(body),
            children: [],
            pageReference: pageReference
        )
    }

    private static func splitLeadingTitle(in content: String) -> (String?, String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("**") {
            let titleStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
            if let titleEnd = trimmed[titleStart...].range(of: "**") {
                let title = String(trimmed[titleStart..<titleEnd.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                var remainder = String(trimmed[titleEnd.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if remainder.hasPrefix("：") || remainder.hasPrefix(":") {
                    remainder.removeFirst()
                }
                return (title.isEmpty ? nil : title, remainder.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        let colonCandidates = ["：", ":"]
            .compactMap { delimiter -> String.Index? in
                trimmed.range(of: delimiter)?.lowerBound
            }
            .sorted()

        if let colonIndex = colonCandidates.first {
            let title = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty, title.count <= 18 {
                let remainderStart = trimmed.index(after: colonIndex)
                let remainder = String(trimmed[remainderStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (cleanInlineMarkdown(title), remainder)
            }
        }

        return (nil, trimmed)
    }

    private static func extractPageReference(from text: String) -> (String, String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasSuffix("页）"),
           let range = trimmed.range(of: "（第", options: .backwards) {
            let pageReference = String(trimmed[range.lowerBound...])
            let body = String(trimmed[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (body, pageReference)
        }

        if trimmed.hasSuffix(")"),
           let range = trimmed.range(of: "(Page", options: [.backwards, .caseInsensitive]) {
            let pageReference = String(trimmed[range.lowerBound...])
            let body = String(trimmed[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (body, pageReference)
        }

        return (trimmed, nil)
    }

    private static func bulletContent(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for marker in ["- ", "* ", "• "] {
            if trimmed.hasPrefix(marker) {
                return String(trimmed.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func leadingWhitespaceCount(in line: String) -> Int {
        var count = 0
        for character in line {
            if character == " " {
                count += 1
            } else if character == "\t" {
                count += 2
            } else {
                break
            }
        }
        return count
    }

    private static func joinedText(_ lhs: String, _ rhs: String) -> String {
        guard !lhs.isEmpty else { return rhs }
        guard !rhs.isEmpty else { return lhs }
        return "\(lhs) \(rhs)"
    }

    private static func cleanInlineMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
    let metrics: ChatPanelMetrics

    var body: some View {
        Image(systemName: role == .user ? "person.crop.circle.fill" : "cpu.fill")
            .font(.system(size: metrics.avatarIconFont, weight: .medium))
            .foregroundStyle(role == .user ? NativeProTheme.accent : NativeProTheme.success)
            .frame(width: metrics.avatarSize, height: metrics.avatarSize)
            .readArcGlass(
                in: Circle(),
                fallbackColor: NativeProTheme.panel.opacity(0.82),
                strokeColor: NativeProTheme.separator,
                tint: role == .user ? NativeProTheme.accent.opacity(0.10) : NativeProTheme.success.opacity(0.10)
            )
    }
}

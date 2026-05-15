import SwiftUI
import Observation
import AppKit

@Observable @MainActor
final class ConversationViewModel {
    var messages: [ChatMessage] = []
    var draft: String = ""
    var isSending = false
    var agentTimeline: [AgentStatusItem] = []
    private(set) var activeConversationID: UUID?
    private(set) var activeProjectID: UUID?
    var activeTitle: String = ""
    private var activeCreatedAt: Date = Date()
    var mentionPickerOpen = false
    var commandPaletteOpen = false

    var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func load(from convo: Conversation) {
        activeConversationID = convo.id
        activeProjectID = convo.projectID
        activeTitle = convo.title
        activeCreatedAt = convo.createdAt
        messages = convo.messages
        draft = ""
        agentTimeline = []
    }

    func resetForConversation(_ convo: Conversation) {
        load(from: Conversation(id: convo.id, title: convo.title, projectID: convo.projectID, messages: [], createdAt: convo.createdAt))
    }

    func snapshotConversation() -> Conversation {
        Conversation(
            id: activeConversationID ?? UUID(),
            title: activeTitle,
            projectID: activeProjectID ?? UUID(),
            messages: messages,
            createdAt: activeCreatedAt,
        )
    }

    func appendUserMessage(_ text: String) {
        messages.append(
            ChatMessage(id: UUID(), role: .user, content: text, timestamp: Date(), agentActivity: nil),
        )
    }

    func appendAssistantMessage(_ text: String) {
        messages.append(
            ChatMessage(id: UUID(), role: .assistant, content: text, timestamp: Date(), agentActivity: nil),
        )
    }

    func clearDraft() {
        draft = ""
    }

    func ingestProgressEnvelope(_ envelope: AgentMessage) {
        let rows = envelope.payload.split(separator: "\n")
        var agentType: AgentType = .scanner
        var status: ActivityStatus = .running

        for row in rows {
            let parts = row.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }
            if parts[0] == "PROGRESS", let parsed = AgentType(rawValue: parts[1]) {
                agentType = parsed
            }
            if parts[0] == "STATUS" {
                switch parts[1] {
                case AgentStatus.success.rawValue: status = .complete
                case AgentStatus.failed.rawValue: status = .failed
                case AgentStatus.blocked.rawValue: status = .failed
                default: status = .running
                }
            }
        }

        let label = envelope.payload.replacingOccurrences(of: "\n", with: " · ")
        let item = AgentStatusItem(
            id: UUID(),
            type: agentType,
            action: String(label.prefix(120)),
            status: status,
            tokensUsed: 0,
            durationMs: 0,
        )

        if let index = agentTimeline.firstIndex(where: { $0.type == agentType }) {
            agentTimeline[index] = item
        } else {
            agentTimeline.append(item)
        }
    }

    func insertMentionToken(path: String) {
        draft.append(path)
        mentionPickerOpen = false
    }
}

struct ConversationPanel: View {
    @Bindable var model: ConversationViewModel
    var projectName: String
    var onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if model.messages.isEmpty {
                EmptyState(
                    systemImage: "bubble.left.and.bubble.right",
                    title: "No messages yet",
                    subtitle: "Describe the change you want. Mnemox orchestrates scanners and writers locally.",
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(model.messages) { message in
                                ConversationBubble(message: message)
                                    .id(message.id)
                            }
                            if model.isSending {
                                HStack(spacing: 8) {
                                    LoadingDots()
                                    Text("Main agent is thinking…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.bottom, 8)
                            }
                            if model.agentTimeline.isEmpty == false {
                                AgentStatusBar(agents: model.agentTimeline)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: model.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
            }

            Divider()
            composer
        }
        .sheet(isPresented: $model.mentionPickerOpen) {
            MentionPicker { url in
                model.insertMentionToken(path: " \(url.path) ")
            }
        }
        .sheet(isPresented: $model.commandPaletteOpen) {
            CommandPaletteView(onSelect: { command in
                model.draft.append(command.insertion + " ")
                model.commandPaletteOpen = false
            })
            .frame(minWidth: 480, minHeight: 320)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.activeTitle)
                .font(.title3.weight(.semibold))
            HStack(spacing: 8) {
                Text("Projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.forward")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                ProjectBadge(name: projectName)
                Spacer()
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Conversation \(model.activeTitle), project \(projectName)")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if model.draft.isEmpty {
                    Text("Plan, Build, / for commands, @ for context")
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .padding(.leading, 2)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $model.draft)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96, maxHeight: 180)
                    .accessibilityLabel("Message composer")
                    .onChange(of: model.draft) { _, newValue in
                        if newValue.last == Character("@") {
                            model.mentionPickerOpen = true
                        }
                        if newValue.last == Character("/") {
                            model.commandPaletteOpen = true
                        }
                    }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))

            HStack {
                MnemoxButton(title: "Send", systemImage: "paperplane.fill", role: .primary, action: onSend)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.trimmedDraft.isEmpty || model.isSending)
                Spacer()
                Text("⌘↵")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = model.messages.last?.id {
            withAnimation {
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }
}

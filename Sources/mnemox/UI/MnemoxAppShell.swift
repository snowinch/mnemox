import Foundation
import Observation

/// Coordinates sidebar, chat, and diff panels without embedding orchestration rules.
@Observable @MainActor
final class MnemoxAppShell {
    var sidebar = SidebarViewModel()
    var conversation = ConversationViewModel()
    var diff = DiffViewModel()

    private(set) var mainAgent: MainAgent?
    private let messageBus = MessageBus()
    private var progressTask: Task<Void, Never>?

    init() {
        seedSampleDataIfNeeded()
        bootstrapEngineIfPossible()
        sidebar.onNewAgent = { [weak self] in
            self?.startNewAgentSession()
        }
    }

    func bootstrapEngineIfPossible() {
        guard let project = sidebar.projects.first else {
            mainAgent = nil
            return
        }

        let root = project.rootURL
        let graph = DependencyGraph(rootPath: root.path, nodes: [:], outgoing: [:], incoming: [:])
        let conventions = ConventionProfile(frameworkTags: [], ruleLines: [])
        guard let client = try? OllamaClient() else {
            mainAgent = nil
            return
        }

        mainAgent = MainAgent(
            root: root,
            graph: graph,
            conventions: conventions,
            modelClient: client,
            messageBus: messageBus,
        )

        Task { await self.subscribeProgress() }
    }

    func startNewAgentSession() {
        let projectID = sidebar.selectedConversation?.projectID ?? sidebar.projects.first?.id ?? UUID()
        let convo = Conversation(id: UUID(), title: "New task", projectID: projectID, messages: [], createdAt: Date())
        sidebar.insertConversation(convo)
        sidebar.selectedConversation = convo
        conversation.resetForConversation(convo)
        diff.clear()
    }

    func selectConversation(_ conversationID: UUID) {
        guard
            let project = sidebar.projects.first(where: { $0.conversations.contains(where: { $0.id == conversationID }) }),
            let convo = project.conversations.first(where: { $0.id == conversationID })
        else {
            return
        }
        sidebar.selectedConversation = convo
        conversation.load(from: convo)
    }

    func sendCurrentDraft() async {
        let text = conversation.trimmedDraft
        guard text.isEmpty == false else {
            return
        }

        guard let agent = mainAgent else {
            conversation.appendUserMessage(text)
            conversation.appendAssistantMessage(
                "Local model runtime is unavailable. Start Ollama/vLLM or check Mnemox runtime settings.",
            )
            conversation.clearDraft()
            return
        }

        conversation.appendUserMessage(text)
        conversation.clearDraft()
        conversation.isSending = true
        conversation.agentTimeline = Self.placeholderTimeline()

        defer { conversation.isSending = false }

        do {
            let outcome = try await agent.process(task: UserTask(title: conversation.activeTitle, detail: text))
            conversation.appendAssistantMessage(outcome.summary)
            diff.applyAggregatedResult(outcome)
            sidebar.refreshActiveAgents(from: outcome)
            conversation.agentTimeline = []
        } catch let failure as MainAgentError {
            conversation.agentTimeline = []
            switch failure {
            case let .preflightBlocked(question):
                conversation.appendAssistantMessage(question)
            case let .verificationFailed(message):
                conversation.appendAssistantMessage("Verification failed: \(message)")
            case let .directiveDecodeFailed(reason):
                conversation.appendAssistantMessage("Plan decode failed: \(reason)")
            }
        } catch {
            conversation.agentTimeline = []
            conversation.appendAssistantMessage("Orchestration error: \(error.localizedDescription)")
        }

        sidebar.persistConversationMessages(conversation.snapshotConversation())
    }

    func submitUserFocusedMessage() {
        Task { await sendCurrentDraft() }
    }

    private func seedSampleDataIfNeeded() {
        guard sidebar.projects.isEmpty else {
            return
        }

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectID = UUID()
        let welcomeID = UUID()
        let project = MnemoxProject(
            id: projectID,
            name: "Current Workspace",
            rootURL: root,
            conversations: [
                Conversation(
                    id: welcomeID,
                    title: "Welcome",
                    projectID: projectID,
                    messages: [
                        ChatMessage(
                            id: UUID(),
                            role: .assistant,
                            content:
                                "Mnemox keeps every model call deterministic. Send a task when your local runtime is ready.",
                            timestamp: Date(),
                            agentActivity: nil,
                        ),
                    ],
                    createdAt: Date(),
                ),
            ],
        )

        sidebar.projects = [project]
        sidebar.selectedConversation = project.conversations.first
        if let convo = project.conversations.first {
            conversation.load(from: convo)
        }
    }

    private func subscribeProgress() async {
        progressTask?.cancel()
        let stream = await messageBus.subscribe(agentID: "mnemox.bus")
        progressTask = Task { @MainActor [weak self] in
            for await envelope in stream where envelope.kind == .progressUpdate {
                self?.conversation.ingestProgressEnvelope(envelope)
            }
        }
    }

    private static func placeholderTimeline() -> [AgentStatusItem] {
        [
            AgentStatusItem(
                id: UUID(),
                type: .scanner,
                action: "Scanning dependencies…",
                status: .running,
                tokensUsed: 0,
                durationMs: 0,
            ),
            AgentStatusItem(
                id: UUID(),
                type: .architect,
                action: "Planning execution…",
                status: .pending,
                tokensUsed: 0,
                durationMs: 0,
            ),
            AgentStatusItem(
                id: UUID(),
                type: .writer,
                action: "Waiting…",
                status: .pending,
                tokensUsed: 0,
                durationMs: 0,
            ),
            AgentStatusItem(
                id: UUID(),
                type: .verifier,
                action: "Waiting…",
                status: .pending,
                tokensUsed: 0,
                durationMs: 0,
            ),
        ]
    }
}

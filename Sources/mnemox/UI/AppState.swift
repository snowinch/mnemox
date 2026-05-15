import Foundation
import Observation

// MARK: - Models

struct Project: Identifiable, Equatable, Codable {
    var id: UUID
    var name: String
    var rootURL: URL
    var conversations: [Conversation]
}

struct Conversation: Identifiable, Equatable, Codable {
    var id: UUID
    var title: String
    var projectID: UUID
    var messages: [Message]
    var isRunning: Bool
    var createdAt: Date
}

struct Message: Identifiable, Equatable, Codable {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var agentSteps: [AgentStep]?
}

enum MessageRole: String, Equatable, Codable {
    case user, assistant, system
}

struct AgentStep: Identifiable, Equatable, Codable {
    var id: UUID
    var agentType: AgentType
    var action: String
    var status: AgentStatus
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case git, browser, terminal, files
    var id: String { rawValue }

    var label: String {
        switch self {
        case .git: "Git"
        case .browser: "Web"
        case .terminal: "Terminal"
        case .files: "Files"
        }
    }

    var icon: String {
        switch self {
        case .git: "arrow.triangle.branch"
        case .browser: "globe"
        case .terminal: "terminal"
        case .files: "folder"
        }
    }
}

// MARK: - App State

@Observable @MainActor
final class AppState {
    var projects: [Project] = []
    var selectedConversationID: UUID?
    var sidebarVisible = true
    var inspectorVisible = false
    var inspectorTab: InspectorTab = .git
    var isNewAgentDraft = true
    var isSending = false
    var runningSteps: [AgentStep] = []
    var draftRepoURL: URL?

    var selectedConversation: Conversation? {
        guard let id = selectedConversationID else { return nil }
        return projects.flatMap(\.conversations).first { $0.id == id }
    }

    func newAgent() {
        isNewAgentDraft = true
        draftRepoURL = nil
    }

    func selectConversation(_ id: UUID) {
        isNewAgentDraft = false
        selectedConversationID = id
    }

    func startConversation(prompt: String, repo: URL?) {
        isNewAgentDraft = false
        let projectID = resolveProjectID(for: repo)
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let convo = Conversation(
            id: UUID(),
            title: trimmed.isEmpty ? "New task" : String(trimmed.prefix(60)),
            projectID: projectID,
            messages: [],
            isRunning: false,
            createdAt: Date()
        )
        insertConversation(convo)
        selectedConversationID = convo.id
        if trimmed.isEmpty == false {
            appendMessage(Message(id: UUID(), role: .user, content: trimmed, timestamp: Date(), agentSteps: nil))
        }
        save()
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        appendMessage(Message(id: UUID(), role: .user, content: trimmed, timestamp: Date(), agentSteps: nil))
        save()
    }

    private func appendMessage(_ message: Message) {
        guard
            let cID = selectedConversationID,
            let pIdx = projects.firstIndex(where: { $0.conversations.contains { $0.id == cID } }),
            let cIdx = projects[pIdx].conversations.firstIndex(where: { $0.id == cID })
        else { return }
        projects[pIdx].conversations[cIdx].messages.append(message)
    }

    private func insertConversation(_ convo: Conversation) {
        guard let pIdx = projects.firstIndex(where: { $0.id == convo.projectID }) else { return }
        projects[pIdx].conversations.insert(convo, at: 0)
    }

    private func resolveProjectID(for url: URL?) -> UUID {
        if let url, let existing = projects.first(where: { $0.rootURL == url }) {
            return existing.id
        }
        if let url {
            let p = Project(id: UUID(), name: url.lastPathComponent, rootURL: url, conversations: [])
            projects.append(p)
            return p.id
        }
        if let first = projects.first { return first.id }
        let p = Project(id: UUID(), name: "Workspace",
                        rootURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                        conversations: [])
        projects.append(p)
        return p.id
    }

    // MARK: - Persistence

    private static let storeURL: URL = {
        let dir = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()))
            .appendingPathComponent("Mnemox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }()

    func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    func load() {
        guard
            let data = try? Data(contentsOf: Self.storeURL),
            let loaded = try? JSONDecoder().decode([Project].self, from: data)
        else { seedWelcome(); return }
        projects = loaded
        selectedConversationID = projects.first?.conversations.first?.id
        isNewAgentDraft = selectedConversationID == nil
    }

    private func seedWelcome() {
        let projectID = UUID()
        let convoID = UUID()
        let project = Project(
            id: projectID,
            name: "Mnemox",
            rootURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            conversations: [
                Conversation(
                    id: convoID,
                    title: "Welcome",
                    projectID: projectID,
                    messages: [
                        Message(
                            id: UUID(),
                            role: .assistant,
                            content: "Local model runtime ready. Send a task when Ollama or vLLM is running.",
                            timestamp: Date(),
                            agentSteps: nil
                        )
                    ],
                    isRunning: false,
                    createdAt: Date()
                )
            ]
        )
        projects = [project]
        selectedConversationID = convoID
        isNewAgentDraft = false
    }
}

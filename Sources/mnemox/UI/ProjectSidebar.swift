import SwiftUI
import Observation
import AppKit

struct MnemoxProject: Identifiable {
    let id: UUID
    let name: String
    let rootURL: URL
    var conversations: [Conversation]
}

struct Conversation: Identifiable {
    let id: UUID
    let title: String
    let projectID: UUID
    var messages: [ChatMessage]
    let createdAt: Date
}

@Observable @MainActor
final class SidebarViewModel {
    var projects: [MnemoxProject] = []
    var selectedConversation: Conversation?
    var activeAgents: [AgentStatusItem] = []
    var searchText: String = ""
    var onNewAgent: (() -> Void)?

    var filteredProjects: [MnemoxProject] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard term.isEmpty == false else {
            return projects
        }

        return projects.map { project in
            let convos = project.conversations.filter { $0.title.lowercased().contains(term) }
            return MnemoxProject(id: project.id, name: project.name, rootURL: project.rootURL, conversations: convos)
        }
        .filter { $0.conversations.isEmpty == false || $0.name.lowercased().contains(term) }
    }

    func insertConversation(_ conversation: Conversation) {
        guard let index = projects.firstIndex(where: { $0.id == conversation.projectID }) else {
            return
        }
        projects[index].conversations.insert(conversation, at: 0)
        selectedConversation = conversation
    }

    func persistConversationMessages(_ conversation: Conversation) {
        guard
            let pIndex = projects.firstIndex(where: { $0.id == conversation.projectID }),
            let cIndex = projects[pIndex].conversations.firstIndex(where: { $0.id == conversation.id })
        else {
            return
        }
        projects[pIndex].conversations[cIndex] = conversation
        if selectedConversation?.id == conversation.id {
            selectedConversation = conversation
        }
    }

    func refreshActiveAgents(from outcome: AggregatedResult) {
        activeAgents = outcome.mxfLog.suffix(4).enumerated().map { index, line in
            AgentStatusItem(
                id: UUID(),
                type: AgentType.allCases[index % AgentType.allCases.count],
                action: String(line.prefix(80)),
                status: .complete,
                tokensUsed: outcome.totalTokensUsed,
                durationMs: 0,
            )
        }
        if activeAgents.isEmpty {
            activeAgents = [
                AgentStatusItem(
                    id: UUID(),
                    type: .writer,
                    action: outcome.summary,
                    status: .complete,
                    tokensUsed: outcome.totalTokensUsed,
                    durationMs: 0,
                ),
            ]
        }
    }
}

struct ProjectSidebar: View {
    @Bindable var model: SidebarViewModel
    var onSelectConversation: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MnemoxButton(title: "New Agent", systemImage: "plus.circle", role: .primary, action: { model.onNewAgent?() })
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .keyboardShortcut("n", modifiers: .command)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(
                    "Search conversations",
                    text: $model.searchText,
                )
                .textFieldStyle(.plain)
                .accessibilityLabel("Search conversations")
            }
            .padding(8)
            .background(Color(nsColor: .underPageBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(model.filteredProjects) { project in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(project.name.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)

                            ForEach(project.conversations) { convo in
                                conversationRow(convo, project: project)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            bottomTray
        }
        .frame(minWidth: 260, idealWidth: 260, maxWidth: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func conversationRow(_ convo: Conversation, project: MnemoxProject) -> some View {
        let isActive = model.selectedConversation?.id == convo.id
        Button {
            onSelectConversation(convo.id)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)

                Text(convo.title)
                    .font(.body)
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: isActive ? .selectedContentBackgroundColor : .clear)),
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .accessibilityLabel("Conversation \(convo.title)")
        .accessibilityHint("Project \(project.name)")
    }

    private var bottomTray: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(NSFullUserName())
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("Local")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Signed in as \(NSFullUserName())")

            Spacer(minLength: 0)

            Button {
                // macOS Settings panel is not part of the SwiftPM shell yet.
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Settings")
        }
        .padding(12)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

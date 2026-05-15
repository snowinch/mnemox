import SwiftUI
import Luminare

struct SidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            newAgentButton
            Divider()
            conversationList
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxHeight: .infinity)
    }

    private var newAgentButton: some View {
        Button {
            state.newAgent()
        } label: {
            Label("New Agent", systemImage: "bolt.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 13, weight: .medium))
                .padding(.vertical, 1)
        }
        .buttonStyle(.luminareProminent)
        .luminareTint(overridingWith: .blue)
        .keyboardShortcut("n", modifiers: .command)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .accessibilityLabel("New Agent")
    }

    private var conversationList: some View {
        LuminareSidebar {
            ForEach(state.projects) { project in
                projectSection(project)
            }
        }
    }

    @ViewBuilder
    private func projectSection(_ project: Project) -> some View {
        if project.conversations.isEmpty == false {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                ForEach(project.conversations) { convo in
                    conversationRow(convo)
                }
            }
        }
    }

    private func conversationRow(_ convo: Conversation) -> some View {
        let isSelected = state.selectedConversationID == convo.id
        return Button {
            state.selectConversation(convo.id)
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(convo.isRunning ? Color.green : (isSelected ? Color.blue : Color(nsColor: .quaternaryLabelColor)))
                    .frame(width: 5, height: 5)

                Text(convo.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))

                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(convo.title)
    }

    private var footer: some View {
        HStack {
            Text("v0.1.0")
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
            Spacer(minLength: 0)
            Button {
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

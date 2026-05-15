import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            conversationList
            Divider().opacity(0.3)
            bottomActions
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 1) {
            actionRow(icon: "plus", label: "New Agent", shortcut: "⌘N") {
                state.newAgent()
            }
        }
        .frame(height: 34)
    }

    private func actionRow(icon: String, label: String, shortcut: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                Spacer(minLength: 0)
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverRowStyle())
    }

    // MARK: - Conversation list

    private var conversationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(state.projects) { project in
                    if !project.conversations.isEmpty {
                        projectSection(project)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func projectSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(project.name.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 3)

            ForEach(project.conversations) { convo in
                conversationRow(convo)
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
                    .fill(isSelected
                          ? Color(nsColor: .secondaryLabelColor)
                          : Color(nsColor: .quaternaryLabelColor).opacity(0.6))
                    .frame(width: 4, height: 4)
                Text(convo.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundStyle(isSelected
                                     ? Color(nsColor: .labelColor)
                                     : Color(nsColor: .tertiaryLabelColor))
                Spacer(minLength: 0)
                if convo.isRunning {
                    Circle()
                        .fill(Color(nsColor: .labelColor).opacity(0.4))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.white.opacity(0.07) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom

    private var bottomActions: some View {
        HStack {
            Spacer(minLength: 0)
            Button {} label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

// MARK: - Hover style

struct HoverRowStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(hovering || configuration.isPressed ? Color.white.opacity(0.05) : Color.clear)
            .onHover { hovering = $0 }
    }
}

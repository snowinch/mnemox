import SwiftUI

struct CenterView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            topBar
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            if !state.sidebarVisible {
                Button {
                    state.sidebarVisible = true
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .help("Show Sidebar")
            }

            if let convo = state.selectedConversation, !state.isNewAgentDraft {
                HStack(spacing: 6) {
                    Circle()
                        .fill(convo.isRunning ? Color.green : Color(nsColor: .tertiaryLabelColor))
                        .frame(width: 6, height: 6)
                    Text(convo.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .lineLimit(1)
                }
            } else {
                Text("New Agent")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }

            Spacer(minLength: 0)

            Button {
                state.inspectorVisible.toggle()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 13))
                    .foregroundStyle(state.inspectorVisible ? Color.blue : Color(nsColor: .secondaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("Toggle Inspector (⌘⇧R)")
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 38)
    }

    @ViewBuilder
    private var content: some View {
        if state.isNewAgentDraft || state.selectedConversation == nil {
            NewAgentView()
        } else if let convo = state.selectedConversation {
            ConversationView(conversation: convo)
        }
    }
}

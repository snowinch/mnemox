import SwiftUI

struct CenterView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.3)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Breadcrumb top bar

    private var topBar: some View {
        HStack(spacing: 0) {
            breadcrumb
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
    }

    @ViewBuilder
    private var breadcrumb: some View {
        if let project = currentProject, let convo = state.selectedConversation, !state.isNewAgentDraft {
            HStack(spacing: 4) {
                Text(project.name)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                Text(convo.title)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .lineLimit(1)
                if convo.isRunning {
                    Circle()
                        .fill(Color(nsColor: .labelColor).opacity(0.5))
                        .frame(width: 4, height: 4)
                }
            }
        } else {
            Text("New Agent")
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
        }
    }

    private var currentProject: Project? {
        guard let convo = state.selectedConversation else { return nil }
        return state.projects.first { $0.id == convo.projectID }
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

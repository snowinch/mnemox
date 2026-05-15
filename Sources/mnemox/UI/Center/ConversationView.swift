import SwiftUI

struct ConversationView: View {
    @Environment(AppState.self) private var state
    let conversation: Conversation

    @State private var inputText = ""
    @State private var branch: String? = nil
    @State private var selectedRepo: URL? = nil

    private var project: Project? {
        state.projects.first { $0.id == conversation.projectID }
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: conversation.id) { await loadBranch() }
        .onAppear { selectedRepo = project?.rootURL }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(conversation.messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }
                    if conversation.isRunning { runningDot }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 12)
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: conversation.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var runningDot: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(Color(nsColor: .quaternaryLabelColor)).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private var inputArea: some View {
        InputBar(text: $inputText, selectedRepo: $selectedRepo, branch: branch) {
            state.sendMessage(inputText)
            inputText = ""
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 6)
    }

    private func loadBranch() async {
        guard let url = project?.rootURL else { return }
        let result = await Task.detached(priority: .utility) {
            shell("git -C '\(url.path)' branch --show-current 2>/dev/null")
        }.value
        let t = result.trimmingCharacters(in: .whitespacesAndNewlines)
        branch = t.isEmpty ? nil : t
    }
}

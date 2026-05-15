import SwiftUI

struct NewAgentView: View {
    @Environment(AppState.self) private var state

    @State private var prompt = ""
    @State private var selectedRepo: URL? = nil

    private var canStart: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                InputBar(text: $prompt, selectedRepo: $selectedRepo) {
                    guard canStart else { return }
                    state.startConversation(prompt: prompt, repo: selectedRepo)
                }
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 24)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("New Agent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(nsColor: .labelColor))
            Text("Describe a task — the agent plans, writes, tests and verifies.")
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
        }
    }
}

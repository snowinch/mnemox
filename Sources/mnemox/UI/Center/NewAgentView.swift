import SwiftUI
import Luminare

struct NewAgentView: View {
    @Environment(AppState.self) private var state

    @State private var prompt = ""
    @State private var repoURL: URL?
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                header
                repoSection
                promptSection
                startButton
            }
            .frame(maxWidth: 640)
            .padding(32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { promptFocused = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.blue)
                Text("New Agent")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .labelColor))
            }
            Text("Describe what you want the agent to do. Pick a repo to ground it in a codebase.")
                .font(.system(size: 12))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        }
    }

    private var repoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Repository (optional)", systemImage: "folder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))

            HStack(spacing: 8) {
                Text(repoURL?.path ?? "No folder selected")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(repoURL != nil ? Color(nsColor: .labelColor) : Color(nsColor: .placeholderTextColor))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Choose…") {
                    pickFolder()
                }
                .buttonStyle(.luminare)

                if repoURL != nil {
                    Button {
                        repoURL = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Task", systemImage: "text.cursor")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))

            ZStack(alignment: .topLeading) {
                if prompt.isEmpty {
                    Text("e.g. Refactor the auth module to use JWT, add unit tests…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(nsColor: .placeholderTextColor))
                        .padding(10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $prompt)
                    .font(.system(size: 13))
                    .focused($promptFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100, maxHeight: 200)
                    .padding(6)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(promptFocused ? Color.blue.opacity(0.5) : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }

    private var startButton: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                state.startConversation(prompt: prompt, repo: repoURL)
            } label: {
                Label("Start", systemImage: "arrow.right")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.luminareProminent)
            .luminareTint(overridingWith: .blue)
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Repo"
        if panel.runModal() == .OK {
            repoURL = panel.url
        }
    }
}

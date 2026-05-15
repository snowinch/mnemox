import SwiftUI

struct InputBar: View {
    @Environment(AppState.self) private var state
    @Binding var text: String
    @Binding var selectedRepo: URL?
    var branch: String? = nil
    var onSend: () -> Void

    @FocusState private var focused: Bool
    @State private var contextUsed: Double = 0.12
    @State private var showRepoPicker = false

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !state.isSending
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Text input ─────────────────────────────────────
            TextField("Plan, Build, / for commands, @ for context", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .lineLimit(1...8)
                .focused($focused)
                .foregroundStyle(Color(nsColor: .labelColor))
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) { return .ignored }
                    handleSend()
                    return .handled
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 16)

            Divider().opacity(0.15)

            // ── Bottom toolbar ─────────────────────────────────
            HStack(spacing: 6) {
                // Context ring
                ContextRing(fraction: contextUsed)
                    .frame(width: 14, height: 14)

                // Repo / branch picker
                Button {
                    showRepoPicker.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(selectedRepo != nil
                                             ? Color(nsColor: .secondaryLabelColor)
                                             : Color(nsColor: .quaternaryLabelColor))
                        if let branch {
                            Text(branch)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                        } else if let repo = selectedRepo {
                            Text(repo.lastPathComponent)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                        } else {
                            Text("/")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                        }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showRepoPicker, arrowEdge: .bottom) {
                    RepoPickerPopover(selectedRepo: $selectedRepo)
                }

                Spacer(minLength: 0)

                // Model selector
                Button {} label: {
                    HStack(spacing: 3) {
                        Text("Auto")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                // Send
                Button { handleSend() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(canSend ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .quaternaryLabelColor))
                        .frame(width: 22, height: 22)
                        .background(canSend ? Color(nsColor: .labelColor) : Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(focused ? Color.white.opacity(0.14) : Color.white.opacity(0.07), lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focused = true }
        }
    }

    private func handleSend() {
        guard canSend else { return }
        onSend()
        text = ""
    }
}

// MARK: - Repo picker popover

struct RepoPickerPopover: View {
    @Environment(AppState.self) private var state
    @Binding var selectedRepo: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.projects.isEmpty {
                Text("No indexed repos")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                ForEach(state.projects) { project in
                    Button {
                        selectedRepo = project.rootURL
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                .frame(width: 14)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(project.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(nsColor: .labelColor))
                                Text(project.rootURL.abbreviatingWithTildeInPath)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                            }
                            Spacer(minLength: 0)
                            if selectedRepo == project.rootURL {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HoverRowStyle())

                    if project.id != state.projects.last?.id {
                        Divider().opacity(0.3).padding(.horizontal, 10)
                    }
                }
            }

            Divider().opacity(0.3)

            // New folder
            Button {
                pickFolder()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        .frame(width: 14)
                    Text("Add folder…")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverRowStyle())
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            selectedRepo = url
        }
        dismiss()
    }
}

// MARK: - Helpers

struct ContextRing: View {
    let fraction: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color(nsColor: .secondaryLabelColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private extension URL {
    var abbreviatingWithTildeInPath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

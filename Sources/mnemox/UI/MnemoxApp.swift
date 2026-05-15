import SwiftUI

private struct SubmitConversationKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct NewAgentKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var submitConversation: (() -> Void)? {
        get { self[SubmitConversationKey.self] }
        set { self[SubmitConversationKey.self] = newValue }
    }

    var mnemoxNewAgent: (() -> Void)? {
        get { self[NewAgentKey.self] }
        set { self[NewAgentKey.self] = newValue }
    }
}

@main
struct MnemoxApp: App {
    @State private var shell = MnemoxAppShell()

    var body: some Scene {
        WindowGroup {
            @Bindable var shell = shell
            ContentView(shell: shell)
                .focusedValue(\FocusedValues.submitConversation, { shell.submitUserFocusedMessage() })
                .focusedValue(\FocusedValues.mnemoxNewAgent, { shell.startNewAgentSession() })
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands { MnemoxCommands() }
    }
}

struct MnemoxCommands: Commands {
    @FocusedValue(\FocusedValues.submitConversation) private var submitConversation
    @FocusedValue(\FocusedValues.mnemoxNewAgent) private var mnemoxNewAgent

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Agent") {
                mnemoxNewAgent?()
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(after: .textEditing) {
            Button("Send Message") {
                submitConversation?()
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}

struct ContentView: View {
    @Bindable var shell: MnemoxAppShell

    var body: some View {
        NavigationSplitView {
            ProjectSidebar(model: shell.sidebar) { conversationID in
                shell.selectConversation(conversationID)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 300)
        } detail: {
            HStack(spacing: 0) {
                ConversationPanel(
                    model: shell.conversation,
                    projectName: resolvedProjectName,
                    onSend: { shell.submitUserFocusedMessage() },
                )
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

                if shell.diff.pendingChanges.isEmpty == false {
                    Divider()
                    DiffView(model: shell.diff)
                        .frame(minWidth: 360, idealWidth: 420, maxWidth: 560)
                }
            }
        }
    }

    private var resolvedProjectName: String {
        guard
            let convo = shell.sidebar.selectedConversation,
            let project = shell.sidebar.projects.first(where: { $0.id == convo.projectID })
        else {
            return "No project"
        }
        return project.name
    }
}

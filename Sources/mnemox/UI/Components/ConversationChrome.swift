import SwiftUI
import AppKit

struct ConversationBubble: View {
    let message: ChatMessage
    @State private var expanded = true

    var body: some View {
        switch message.role {
        case .user:
            bubble(alignment: .trailing, fill: Color.accentColor.opacity(0.25)) {
                Text(message.content)
                    .textSelection(.enabled)
            }
        case .assistant, .system:
            bubble(alignment: .leading, fill: Color(nsColor: .controlBackgroundColor)) {
                AssistantContent(text: message.content)
            }
        case .agentActivity:
            DisclosureGroup(isExpanded: $expanded) {
                Text(message.content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } label: {
                HStack(spacing: 8) {
                    if let activity = message.agentActivity {
                        AgentBadge(agentType: activity.agentType)
                    }
                    Text(message.content)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .underPageBackgroundColor)))
        }
    }

    private func bubble<Content: View>(alignment: HorizontalAlignment, fill: Color, @ViewBuilder content: () -> Content)
        -> some View
    {
        HStack {
            if alignment == .trailing {
                Spacer(minLength: 60)
            }
            content()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(fill))
            if alignment == .leading {
                Spacer(minLength: 60)
            }
        }
    }
}

struct AssistantContent: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(parsedChunks().enumerated()), id: \.offset) { _, chunk in
                switch chunk {
                case let .text(value):
                    Text(value)
                        .textSelection(.enabled)
                case let .code(code, lang):
                    CodeBlock(code: code, languageHint: lang)
                }
            }
        }
    }

    private enum Chunk {
        case text(String)
        case code(String, String?)
    }

    private func parsedChunks() -> [Chunk] {
        var results: [Chunk] = []
        let pattern = #"```(\w+)?\n([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(text)]
        }
        let ns = text as NSString
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                let between = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                if between.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    results.append(.text(between))
                }
            }
            let langRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            let lang = langRange.location != NSNotFound ? ns.substring(with: langRange) : nil
            let code = codeRange.location != NSNotFound ? ns.substring(with: codeRange) : ""
            results.append(.code(code, lang))
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            let tail = ns.substring(from: cursor)
            if tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                results.append(.text(tail))
            }
        }
        return results.isEmpty ? [.text(text)] : results
    }
}

struct MentionPicker: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attach file context")
                .font(.headline)
            Text("Pick a file from disk to insert its absolute path into the composer.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Choose file") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                if panel.runModal() == .OK, let url = panel.url {
                    onPick(url)
                }
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Choose file for mention")
        }
        .padding(24)
        .frame(minWidth: 360)
    }
}

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (SlashCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Commands")
                .font(.headline)
                .padding()
            List(SlashCommand.all) { command in
                Button {
                    onSelect(command)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(command.title).font(.body.weight(.semibold))
                        Text(command.summary).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SlashCommand: Identifiable {
    var id: String { title }
    let title: String
    let summary: String
    let insertion: String

    static let all: [SlashCommand] = [
        SlashCommand(title: "Plan", summary: "Ask the architect to produce an execution plan.", insertion: "/plan"),
        SlashCommand(title: "Scan", summary: "Run repository scan for imports and structure.", insertion: "/scan"),
        SlashCommand(title: "Explain", summary: "Request a plain-language explanation.", insertion: "/explain"),
        SlashCommand(title: "Test", summary: "Route orchestration toward TestAgent output.", insertion: "/test"),
    ]
}

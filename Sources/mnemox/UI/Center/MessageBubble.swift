import SwiftUI

struct MessageBubble: View {
    let message: Message
    @State private var stepsExpanded = false
    @State private var hovering = false
    @State private var editing = false
    @State private var editBuffer = ""

    var body: some View {
        switch message.role {
        case .user:    userBubble
        case .assistant: assistantBubble
        case .system:  systemBubble
        }
    }

    // MARK: - User bubble

    private var userBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer(minLength: 80)

            VStack(alignment: .trailing, spacing: 4) {
                // Edit controls on hover
                if hovering && !editing {
                    HStack(spacing: 6) {
                        iconBtn("pencil") { startEdit() }
                        iconBtn("arrow.uturn.left") { }
                    }
                    .transition(.opacity)
                }

                if editing {
                    editingView
                } else {
                    Text(message.content)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
    }

    private var editingView: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField("", text: $editBuffer, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(1...10)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )

            HStack(spacing: 6) {
                Button("Cancel") { editing = false }
                    .buttonStyle(GhostSmallStyle())
                Button("Send") { editing = false }
                    .buttonStyle(GhostSmallStyle())
            }
        }
    }

    private func startEdit() {
        editBuffer = message.content
        editing = true
    }

    // MARK: - Assistant bubble

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let steps = message.agentSteps, !steps.isEmpty {
                agentStepsDisclosure(steps)
            }
            if !message.content.isEmpty {
                contentView(message.content)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - System

    private var systemBubble: some View {
        Text(message.content)
            .font(.system(size: 10))
            .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    // MARK: - Content renderer

    @ViewBuilder
    private func contentView(_ text: String) -> some View {
        let segments = parseSegments(text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .text(let t):
                    Text(t)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .code(let lang, let code):
                    CodeBlock(code: code, language: lang)
                }
            }
        }
    }

    // MARK: - Agent steps

    private func agentStepsDisclosure(_ steps: [AgentStep]) -> some View {
        DisclosureGroup(
            isExpanded: $stepsExpanded,
            content: {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(steps) { step in
                        HStack(spacing: 6) {
                            stepIcon(step.status)
                            Text(step.action)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(step.agentType.rawValue)
                                .font(.system(size: 9))
                                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)
            },
            label: {
                Text("\(steps.count) step\(steps.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func stepIcon(_ status: AgentStatus) -> some View {
        Group {
            switch status {
            case .success: Image(systemName: "checkmark").foregroundStyle(Color(nsColor: .secondaryLabelColor))
            case .failed:  Image(systemName: "xmark").foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            case .blocked: Image(systemName: "pause").foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            case .skipped: Image(systemName: "minus").foregroundStyle(Color(nsColor: .quaternaryLabelColor))
            }
        }
        .font(.system(size: 9))
        .frame(width: 12)
    }

    // MARK: - Helpers

    private func iconBtn(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ghost small button

struct GhostSmallStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(configuration.isPressed ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Segment parser

private enum ContentSegment { case text(String); case code(String, String) }

private func parseSegments(_ text: String) -> [ContentSegment] {
    var result: [ContentSegment] = []
    var remaining = text[text.startIndex...]
    while !remaining.isEmpty {
        if let fenceStart = remaining.range(of: "```") {
            let before = String(remaining[..<fenceStart.lowerBound])
            if !before.isEmpty { result.append(.text(before)) }
            let after = remaining[fenceStart.upperBound...]
            let nl = after.firstIndex(of: "\n") ?? after.endIndex
            let lang = String(after[..<nl])
            let codeStart = nl < after.endIndex ? after.index(after: nl) : after.endIndex
            let codeContent = after[codeStart...]
            if let end = codeContent.range(of: "```") {
                var code = String(codeContent[..<end.lowerBound])
                if code.hasSuffix("\n") { code = String(code.dropLast()) }
                result.append(.code(lang, code))
                remaining = codeContent[end.upperBound...]
            } else {
                result.append(.text("```\(lang)\n\(codeContent)"))
                break
            }
        } else {
            result.append(.text(String(remaining)))
            break
        }
    }
    return result
}

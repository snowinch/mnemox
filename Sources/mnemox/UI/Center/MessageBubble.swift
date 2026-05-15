import SwiftUI

struct MessageBubble: View {
    let message: Message
    @State private var stepsExpanded = false

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .system:
            systemBubble
        }
    }

    private var userBubble: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 60)
            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(Color.white)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let steps = message.agentSteps, !steps.isEmpty {
                agentStepsView(steps)
            }

            if !message.content.isEmpty {
                renderedContent(message.content)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var systemBubble: some View {
        Text(message.content)
            .font(.system(size: 11))
            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private func renderedContent(_ text: String) -> some View {
        let segments = parseSegments(text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
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

    private func agentStepsView(_ steps: [AgentStep]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { stepsExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: stepsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    Text("\(steps.count) agent step\(steps.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if stepsExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(steps) { step in
                        AgentStepRow(step: step)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

struct AgentStepRow: View {
    let step: AgentStep

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            Text(step.action)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(step.agentType.rawValue)
                .font(.system(size: 10))
                .foregroundStyle(Color(nsColor: .quaternaryLabelColor))
        }
        .padding(.vertical, 3)
    }

    private var statusIcon: some View {
        Group {
            switch step.status {
            case .success:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.red)
            case .blocked:
                Image(systemName: "pause.circle.fill").foregroundStyle(Color.orange)
            case .skipped:
                Image(systemName: "minus.circle").foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
        }
        .font(.system(size: 11))
    }
}

// MARK: - Simple markdown segment parser

private enum ContentSegment {
    case text(String)
    case code(String, String)
}

private func parseSegments(_ text: String) -> [ContentSegment] {
    var result: [ContentSegment] = []
    var remaining = text[text.startIndex...]

    while !remaining.isEmpty {
        if let fenceStart = remaining.range(of: "```") {
            let before = String(remaining[remaining.startIndex ..< fenceStart.lowerBound])
            if !before.isEmpty { result.append(.text(before)) }

            let afterFence = remaining[fenceStart.upperBound...]
            let firstNewline = afterFence.firstIndex(of: "\n") ?? afterFence.endIndex
            let lang = String(afterFence[afterFence.startIndex ..< firstNewline])
            let codeStart = firstNewline < afterFence.endIndex ? afterFence.index(after: firstNewline) : afterFence.endIndex
            let codeContent = afterFence[codeStart...]

            if let endFence = codeContent.range(of: "```") {
                let code = String(codeContent[codeContent.startIndex ..< endFence.lowerBound])
                result.append(.code(lang, code.hasSuffix("\n") ? String(code.dropLast()) : code))
                remaining = codeContent[endFence.upperBound...]
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

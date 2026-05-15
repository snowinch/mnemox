import SwiftUI
import Observation
import AppKit

enum ActivityStatus: String, CaseIterable {
    case pending
    case running
    case complete
    case failed
}

struct AgentStatusItem: Identifiable {
    let id: UUID
    let type: AgentType
    let action: String
    let status: ActivityStatus
    var tokensUsed: Int
    var durationMs: Int
}

struct AgentStatusBar: View {
    let agents: [AgentStatusItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(agents) { agent in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    statusDot(for: agent.status)
                        .accessibilityHidden(true)

                    AgentBadge(agentType: agent.type)

                    Text(agent.action)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text(statusLabel(agent.status))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(label(for: agent.type)), \(agent.action), \(statusLabel(agent.status))")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .underPageBackgroundColor)))
    }

    private func statusDot(for status: ActivityStatus) -> some View {
        let name: String
        let color: Color
        switch status {
        case .pending:
            name = "circle"
            color = .secondary.opacity(0.35)
        case .running:
            name = "circle.inset.filled"
            color = .accentColor
        case .complete:
            name = "checkmark.circle.fill"
            color = .green
        case .failed:
            name = "xmark.octagon.fill"
            color = .red
        }

        return Image(systemName: name)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .font(.caption)
    }

    private func statusLabel(_ status: ActivityStatus) -> String {
        switch status {
        case .pending: "pending"
        case .running: "running"
        case .complete: "complete"
        case .failed: "failed"
        }
    }

    private func label(for type: AgentType) -> String {
        switch type {
        case .scanner: "ScannerAgent"
        case .architect: "ArchitectAgent"
        case .writer: "WriterAgent"
        case .refactor: "RefactorAgent"
        case .i18n: "I18nAgent"
        case .test: "TestAgent"
        case .verifier: "VerifierAgent"
        }
    }
}

import SwiftUI
import AppKit

enum MessageRole: String, Sendable {
    case user
    case assistant
    case system
    case agentActivity
}

struct AgentActivityItem: Sendable {
    let agentType: AgentType
    let action: String
    let status: ActivityStatus
}

struct ChatMessage: Identifiable, Sendable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let agentActivity: AgentActivityItem?
}

enum MnemoxButtonRole {
    case primary
    case secondary
    case destructive
}

struct MnemoxButton: View {
    let title: String
    var systemImage: String?
    var role: MnemoxButtonRole = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .frame(maxWidth: role == .primary ? .infinity : nil)
        }
        .controlSize(.large)
        .accessibilityLabel(title)
        .modifier(MnemoxButtonChrome(role: role))
    }
}

private struct MnemoxButtonChrome: ViewModifier {
    let role: MnemoxButtonRole

    func body(content: Content) -> some View {
        switch role {
        case .primary:
            content.buttonStyle(.borderedProminent)
        case .secondary:
            content.buttonStyle(.bordered)
        case .destructive:
            content.buttonStyle(.borderedProminent).tint(.red)
        }
    }
}

struct CodeBlock: View {
    let code: String
    let languageHint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let languageHint {
                    Text(languageHint)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy code")
            }
            ScrollView(.horizontal, showsIndicators: true) {
                Text(lexHighlighted(code: code, hint: languageHint))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
    }
}

struct AgentBadge: View {
    let agentType: AgentType

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
            Text(shortLabel)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        .accessibilityLabel("\(shortLabel) agent")
    }

    private var shortLabel: String {
        switch agentType {
        case .scanner: "Scanner"
        case .architect: "Architect"
        case .writer: "Writer"
        case .refactor: "Refactor"
        case .i18n: "I18n"
        case .test: "Test"
        case .verifier: "Verifier"
        }
    }
}

struct ProjectBadge: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
            .accessibilityLabel("Project \(name)")
    }
}

struct LoadingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(index == phase % 3 ? 1.0 : 0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .onReceive(timer) { _ in
            phase += 1
        }
        .accessibilityLabel("Loading")
    }
}

struct EmptyState: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Lightweight highlighter (semantic colors only)

private func lexHighlighted(code: String, hint _: String?) -> AttributedString {
    var attributed = AttributedString(code)
    if let regex = try? NSRegularExpression(pattern: #"\"([^\"\\]|\\.)*\""#, options: []) {
        let ns = code as NSString
        for match in regex.matches(in: code, range: NSRange(location: 0, length: ns.length)) {
            guard let range = Range(match.range, in: code) else {
                continue
            }
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed) else {
                continue
            }
            attributed[lower..<upper].foregroundColor = NSColor.systemGreen
        }
    }

    return attributed
}

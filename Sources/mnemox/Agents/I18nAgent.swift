import Foundation

/// Locale-aware executor detecting structural gaps deterministically before optional translation synthesis.
public struct I18nAgent: BaseAgent {
    public let id: AgentID
    public let type: AgentType = .i18n

    private let graph: DependencyGraph
    private let conventions: ConventionProfile
    private let client: ModelClient

    public init(id: AgentID, graph: DependencyGraph, conventions: ConventionProfile, client: ModelClient) {
        self.id = id
        self.graph = graph
        self.conventions = conventions
        self.client = client
    }

    public func execute(task: AtomicTask) async throws -> AgentResult {
        let started = Date()
        var log: [String] = []

        let localePaths = Self.localeCandidates(from: graph)
        log.append("I18N/LOCALE-PATHS \(localePaths.joined(separator: ","))")

        for path in localePaths.prefix(12) {
            log.append("#\(path) locale-scan")
        }

        guard localePaths.isEmpty == false else {
            let elapsed = Self.ms(from: started)
            return AgentResult(
                agentID: id,
                task: task,
                output: nil,
                mxfLog: log,
                tokensUsed: 0,
                durationMs: elapsed,
                status: .skipped,
            )
        }

        let manifest = localePaths.joined(separator: "\n")
        let prompt = ModelPrompt(
            system: """
            Translation specialist. Emit JSON object mapping locale keys to translated strings only.
            Never emit Markdown fences or UI component code.
            """,
            context: manifest,
            task: """
            TARGET FILE \(task.targetFile)
            MXF RULES
            \(conventions.encodeToMXF())

            CONTEXT-SHARD
            \(task.mxfContext)
            """,
            outputContract: "OUT:json-only forbid-markdown forbid-hardcoded-nonjson",
            temperature: 0.2,
            maxTokens: 400,
        )

        log.append("I18N/PROMPT\n\(prompt.system)\n---\n\(prompt.context)\n---\n\(prompt.task)")

        let response = try await client.complete(prompt: prompt)
        let contract = OutputContract(language: "json", targetFile: task.targetFile)
        let parsed = try ResponseParser.parse(response, expected: contract)

        log.append("I18N/RESPONSE\n\(response.content)")
        log.append(MXFEncoder.encode(I18nAgentWire.responseEnvelope(agentID: id, task: task, parsed: parsed)))

        let elapsed = Self.ms(from: started)
        let status: AgentStatus = parsed.isComplete ? .success : .failed

        return AgentResult(
            agentID: id,
            task: task,
            output: parsed,
            mxfLog: log,
            tokensUsed: response.tokensUsed,
            durationMs: elapsed,
            status: status,
        )
    }

    private static func localeCandidates(from graph: DependencyGraph) -> [String] {
        graph.trackedRelativePaths.filter { path in
            let lower = path.lowercased()
            return lower.contains("/locales/") || lower.contains("/locale/") || lower.contains("i18n")
        }
        .sorted()
    }

    private static func ms(from start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}

private enum I18nAgentWire {
    static func responseEnvelope(agentID: AgentID, task: AtomicTask, parsed: ActionResult) -> AgentMessage {
        let payload = """
        RESULT agent:\(agentID)
        TARGET:#\(task.targetFile)
        LANG:\(parsed.language)
        COMPLETE:\(parsed.isComplete ? "true" : "false")
        CODE-BEGIN
        \(parsed.code)
        CODE-END
        """

        return AgentMessage(
            id: UUID(),
            from: agentID,
            to: "mnemox.main",
            kind: .resultReady,
            payload: payload,
            timestamp: Date(),
            correlationID: nil,
        )
    }
}

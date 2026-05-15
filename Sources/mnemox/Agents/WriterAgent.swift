import Foundation

/// Single-file mutation executor honoring PromptEngine overlays.
public struct WriterAgent: BaseAgent {
    public let id: AgentID
    public let type: AgentType = .writer

    private let root: URL
    private let graph: DependencyGraph
    private let conventions: ConventionProfile
    private let client: ModelClient

    public init(id: AgentID, root: URL, graph: DependencyGraph, conventions: ConventionProfile, client: ModelClient) {
        self.id = id
        self.root = root
        self.graph = graph
        self.conventions = conventions
        self.client = client
    }

    public func execute(task: AtomicTask) async throws -> AgentResult {
        let started = Date()
        var log: [String] = []

        let targetURL = root.appendingPathComponent(task.targetFile)
        let neighborhood = graph.dependencies(of: targetURL)
        let prompt = try PromptEngine.build(task: task, conventions: conventions, context: neighborhood)

        log.append("WRITE/PROMPT\n\(prompt.system)\n---\n\(prompt.context)\n---\n\(prompt.task)")

        let response = try await client.complete(prompt: prompt)

        let contract = OutputContract(language: WriterAgent.languageTag(for: task.targetFile), targetFile: task.targetFile)
        let parsed = try ResponseParser.parse(response, expected: contract)

        log.append("WRITE/RESPONSE\n\(response.content)")
        log.append(MXFEncoder.encode(ModelLedger.responseEnvelope(agentID: id, task: task, parsed: parsed)))

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

    private static func languageTag(for relativePath: String) -> String {
        let lower = relativePath.lowercased()
        if lower.hasSuffix(".swift") { return "swift" }
        if lower.hasSuffix(".ts") || lower.hasSuffix(".tsx") { return "typescript" }
        if lower.hasSuffix(".js") || lower.hasSuffix(".jsx") { return "javascript" }
        if lower.hasSuffix(".vue") { return "vue" }
        if lower.hasSuffix(".py") { return "python" }
        return "plaintext"
    }

    private static func ms(from start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}

private enum ModelLedger {
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

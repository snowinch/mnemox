import Foundation

/// Planning specialist emitting MXF [`ExecutionPlan`] ladders via the shared runtime.
public struct ArchitectAgent: BaseAgent {
    public let id: AgentID
    public let type: AgentType = .architect

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

        let prompt = ModelPrompt(
            system: """
            Architect agent. Respond with Mnemox PLAN MXF only.
            Rows must begin with PLAN:action/target followed by indented steps `  N:CODE directive`.
            """,
            context: graph.encodeToMXF(),
            task: """
            PLANNING-SHARD
            \(task.mxfContext)
            """,
            outputContract: "OUT:mxf PLAN rows forbid-prose forbid-markdown",
            temperature: 0.3,
            maxTokens: 512,
        )

        log.append("ARCH/PROMPT-SYSTEM\n\(prompt.system)")
        log.append("ARCH/PROMPT-CONTEXT\n\(prompt.context)")
        log.append("ARCH/PROMPT-TASK\n\(prompt.task)")

        let response = try await client.complete(prompt: prompt)
        log.append("ARCH/RESPONSE\n\(response.content)")

        let contract = OutputContract(language: "mxf", targetFile: nil, shapeDirective: "plan-wire")
        let parsed = try ResponseParser.parse(response, expected: contract)

        let envelope = AgentMessage(
            id: UUID(),
            from: id,
            to: "mnemox.main",
            kind: .resultReady,
            payload: parsed.code,
            timestamp: Date(),
            correlationID: nil,
        )
        log.append(MXFEncoder.encode(envelope))

        let elapsed = Self.ms(from: started)
        return AgentResult(
            agentID: id,
            task: task,
            output: parsed,
            mxfLog: log,
            tokensUsed: response.tokensUsed,
            durationMs: elapsed,
            status: parsed.isComplete ? .success : .failed,
        )
    }

    private static func ms(from start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}

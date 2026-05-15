import Foundation

/// Low-temperature reshaping executor mirroring [`WriterAgent`] with deterministic tuning.
public struct RefactorAgent: BaseAgent {
    public let id: AgentID
    public let type: AgentType = .refactor

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
        let draft = try PromptEngine.build(task: task, conventions: conventions, context: neighborhood)

        let prompt = ModelPrompt(
            system: draft.system,
            context: draft.context,
            task: draft.task,
            outputContract: draft.outputContract,
            temperature: 0.1,
            maxTokens: draft.maxTokens,
        )

        log.append("REFACTOR/PROMPT\n\(prompt.system)\n---\n\(prompt.context)\n---\n\(prompt.task)")

        let response = try await client.complete(prompt: prompt)

        let contract = OutputContract(language: RefactorAgent.languageTag(for: task.targetFile), targetFile: task.targetFile)
        let parsed = try ResponseParser.parse(response, expected: contract)

        log.append("REFACTOR/RESPONSE\n\(response.content)")

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

import Foundation

/// Generates focused regression artifacts based on MXF-encoded interfaces.
public struct TestAgent: BaseAgent {
    public let id: AgentID
    public let type: AgentType = .test

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

        let generationTask = AtomicTask(
            targetFile: Self.testCompanionPath(for: task.targetFile),
            action: "generate-tests-component",
            mxfContext: task.mxfContext,
        )

        let draft = try PromptEngine.build(task: generationTask, conventions: conventions, context: neighborhood)

        let prompt = ModelPrompt(
            system: draft.system,
            context: draft.context,
            task: draft.task,
            outputContract: draft.outputContract,
            temperature: 0.3,
            maxTokens: max(draft.maxTokens, 480),
        )

        log.append("TEST/PROMPT\n\(prompt.system)\n---\n\(prompt.context)\n---\n\(prompt.task)")

        let response = try await client.complete(prompt: prompt)

        let contract = OutputContract(language: Self.languageTag(for: generationTask.targetFile), targetFile: generationTask.targetFile)
        let parsed = try ResponseParser.parse(response, expected: contract)

        log.append("TEST/RESPONSE\n\(response.content)")

        let elapsed = Self.ms(from: started)
        let status: AgentStatus = parsed.isComplete ? .success : .failed

        return AgentResult(
            agentID: id,
            task: generationTask,
            output: parsed,
            mxfLog: log,
            tokensUsed: response.tokensUsed,
            durationMs: elapsed,
            status: status,
        )
    }

    private static func testCompanionPath(for relativePath: String) -> String {
        let nsPath = relativePath as NSString
        let directory = nsPath.deletingLastPathComponent
        let filename = nsPath.lastPathComponent as NSString
        let base = filename.deletingPathExtension
        let suffix = filename.pathExtension.lowercased()

        if suffix == "swift" {
            return URL(fileURLWithPath: directory).appendingPathComponent("\(base)Tests.swift").path
        }

        return URL(fileURLWithPath: directory).appendingPathComponent("\(base).spec.ts").path
    }

    private static func languageTag(for relativePath: String) -> String {
        let lower = relativePath.lowercased()
        if lower.hasSuffix(".swift") { return "swift" }
        if lower.hasSuffix(".ts") || lower.hasSuffix(".tsx") { return "typescript" }
        return "javascript"
    }

    private static func ms(from start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}

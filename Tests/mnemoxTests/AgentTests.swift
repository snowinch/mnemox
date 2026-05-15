import XCTest

@testable import mnemox

final class AgentTests: XCTestCase {
    func testAgentFactoryClassifiesRenameMoveTasks() {
        let factory = AgentFactory()
        let conventions = ConventionProfile(frameworkTags: [], ruleLines: [])
        let pipeline = factory.agents(for: UserTask(detail: "rename helper.ts symbols"), conventions: conventions)
        XCTAssertEqual(pipeline, [.scanner, .writer, .verifier])
    }

    func testAgentFactoryAddsI18nForPropsWithCopy() {
        let factory = AgentFactory()
        let conventions = ConventionProfile(frameworkTags: [], ruleLines: [])
        let pipeline = factory.agents(for: UserTask(detail: "add prop label text to dashboard card"), conventions: conventions)
        XCTAssertEqual(pipeline, [.scanner, .writer, .i18n, .verifier])
    }

    func testAgentFactoryAddsI18nForNuxtComponents() {
        let factory = AgentFactory()
        let conventions = ConventionProfile(frameworkTags: ["@nuxt"], ruleLines: [])
        let pipeline = factory.agents(for: UserTask(detail: "create component SectionHero.vue"), conventions: conventions)
        XCTAssertEqual(pipeline, [.scanner, .architect, .writer, .i18n, .verifier])
    }

    func testAgentFactoryHandlesRefactorPipeline() {
        let factory = AgentFactory()
        let conventions = ConventionProfile(frameworkTags: [], ruleLines: [])
        let pipeline = factory.agents(for: UserTask(detail: "refactor auth.ts structure"), conventions: conventions)
        XCTAssertEqual(pipeline, [.scanner, .architect, .refactor, .verifier])
    }

    func testAgentFactoryHandlesFeaturePipeline() {
        let factory = AgentFactory()
        let conventions = ConventionProfile(frameworkTags: [], ruleLines: [])
        let pipeline = factory.agents(for: UserTask(detail: "implement feature export analytics"), conventions: conventions)
        XCTAssertEqual(pipeline, [.scanner, .architect, .writer, .i18n, .test, .verifier])
    }

    func testAgentFactoryHandlesBugfixPipeline() {
        let factory = AgentFactory()
        let conventions = ConventionProfile(frameworkTags: [], ruleLines: [])
        let pipeline = factory.agents(for: UserTask(detail: "fix bug inside checkout module"), conventions: conventions)
        XCTAssertEqual(pipeline, [.scanner, .writer, .verifier])
    }

    func testResultAggregatorMergesWriterOutputs() {
        let aggregator = ResultAggregator()

        let writerTask = AtomicTask(targetFile: "alpha.ts", action: "update-file", mxfContext: "")
        let writerPayload = ActionResult(
            code: "export const alpha = 1",
            language: "typescript",
            targetFile: "alpha.ts",
            isComplete: true,
            validationHints: [],
        )

        let results = [
            AgentResult(
                agentID: "writer",
                task: writerTask,
                output: writerPayload,
                mxfLog: ["WRITE:stub"],
                tokensUsed: 12,
                durationMs: 4,
                status: .success,
            ),
            AgentResult(
                agentID: "scanner",
                task: writerTask,
                output: nil,
                mxfLog: ["SCAN:stub"],
                tokensUsed: 0,
                durationMs: 1,
                status: .success,
            ),
        ]

        let merged = aggregator.aggregate(results: results)

        XCTAssertEqual(merged.fileChanges.count, 1)
        XCTAssertEqual(merged.fileChanges.first?.path.lastPathComponent, "alpha.ts")
        XCTAssertTrue(merged.fileChanges.first?.newContent.contains("alpha") ?? false)
        XCTAssertEqual(merged.totalTokensUsed, 12)
        XCTAssertTrue(merged.mxfLog.contains(where: { $0 == "WRITE:stub" }))
        XCTAssertTrue(merged.mxfLog.contains(where: { $0 == "SCAN:stub" }))
        XCTAssertTrue(merged.requiresUserApproval)
    }

    func testVerifierDetectsIncompleteResponses() {
        let conventions = ConventionProfile(frameworkTags: [], ruleLines: [])
        let verifier = VerifierAgent(id: "unit.verifier", conventions: conventions)

        let faulty = ActionResult(
            code: "partial",
            language: "typescript",
            targetFile: "sample.ts",
            isComplete: false,
            validationHints: ["finish-reason-length"],
        )

        let verdict = verifier.verify(action: faulty)
        XCTAssertFalse(verdict.passed)
        XCTAssertTrue(verdict.violations.contains(where: { $0.location == "finish" }))
    }

    func testMainAgentBlocksWhenPreflightFails() async throws {
        let root = try makeScratchDirectory()
        try """
        export const shared = 1
        """.write(to: root.appendingPathComponent("alpha.ts"), atomically: true, encoding: .utf8)

        let snapshot = try await ProjectScanner().scan(root: root)
        let graph = try await DependencyGraph.build(from: snapshot)
        let conventions = ConventionProfile(frameworkTags: [], ruleLines: [])
        let scripted = ScriptedModelClient(queue: [])
        let bus = MessageBus()

        let orchestrator = MainAgent(
            root: root,
            graph: graph,
            conventions: conventions,
            modelClient: scripted,
            messageBus: bus,
        )

        let ambiguous = UserTask(detail: "Add hero component with animations")

        do {
            _ = try await orchestrator.process(task: ambiguous)
            XCTFail("Expected orchestrator to halt on ambiguity guard.")
        } catch MainAgentError.preflightBlocked(let question) {
            XCTAssertFalse(question.isEmpty)
        }
    }
}

// MARK: - Test doubles

private final class ScriptedModelBackend: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [ModelResponse]

    init(responses: [ModelResponse]) {
        self.responses = responses
    }

    func next() throws -> ModelResponse {
        lock.lock()
        defer { lock.unlock() }
        guard responses.isEmpty == false else {
            throw ModelError.unavailable("scripted queue empty")
        }
        return responses.removeFirst()
    }
}

private struct ScriptedModelClient: ModelClient {
    private let backend: ScriptedModelBackend

    init(queue responses: [ModelResponse]) {
        backend = ScriptedModelBackend(responses: responses)
    }

    var modelID: String {
        "scripted-model"
    }

    var isAvailable: Bool {
        get async {
            true
        }
    }

    func complete(prompt: ModelPrompt) async throws -> ModelResponse {
        try backend.next()
    }

    func stream(prompt: ModelPrompt) -> AsyncThrowingStream<ModelChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private extension AgentTests {
    func makeScratchDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mnemox-agent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

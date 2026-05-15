import Foundation

/// Blocking orchestrator failures surfaced to SwiftUI instead of silent drift.
public enum MainAgentError: Error, Sendable, Equatable {
    case preflightBlocked(question: String)
    case verificationFailed(message: String)
    case directiveDecodeFailed(reason: String)
}

private enum ExecutionDirectiveCodec {
    static func atomicTask(from step: ExecutionPlan.Step) throws -> AtomicTask {
        guard let data = step.directive.data(using: .utf8) else {
            throw MainAgentError.directiveDecodeFailed(reason: "utf8")
        }

        do {
            return try JSONDecoder().decode(AtomicTask.self, from: data)
        } catch {
            throw MainAgentError.directiveDecodeFailed(reason: String(step.directive.prefix(120)))
        }
    }
}

/// Primary façade sequencing deterministic gates before executor dispatch.
public actor MainAgent {
    private let root: URL
    private let graph: DependencyGraph
    private let conventions: ConventionProfile
    private let modelClient: ModelClient
    private let messageBus: MessageBus
    private let agentPool: AgentPool

    private let preflight = PreFlightSystem()
    private let decomposer = TaskDecomposer()
    private let snapshotManager = SnapshotManager()
    private let factory = AgentFactory()
    private let aggregator = ResultAggregator()

    public init(
        root: URL,
        graph: DependencyGraph,
        conventions: ConventionProfile,
        modelClient: ModelClient,
        messageBus: MessageBus,
    ) {
        self.root = root.standardizedFileURL
        self.graph = graph
        self.conventions = conventions
        self.modelClient = modelClient
        self.messageBus = messageBus
        self.agentPool = AgentPool(
            sharedClient: modelClient,
            graph: graph,
            conventions: conventions,
            root: root.standardizedFileURL,
        )
    }

    public func process(task: UserTask) async throws -> AggregatedResult {
        let correlation = UUID()

        let runway = try await preflight.run(task: task, graph: graph, conventions: conventions)
        guard runway.passed else {
            throw MainAgentError.preflightBlocked(question: runway.question ?? "Task blocked during pre-flight.")
        }

        var plan = try await decomposer.decompose(task: task, graph: graph, conventions: conventions)
        let pipeline = factory.agents(for: task, conventions: conventions)

        let snapshot = try await snapshotManager.createSnapshot(root: root)
        let verifier = VerifierAgent(id: "mnemox.verifier.pipeline", conventions: conventions)

        var results: [AgentResult] = []

        if pipeline.contains(.scanner) {
            let scanTask = Self.bootstrapScanTask(for: plan)
            let scanResult = try await dispatch(type: .scanner, task: scanTask, correlation: correlation)
            results.append(scanResult)
        }

        if pipeline.contains(.architect) {
            let shard = """
            USER \(task.detail)

            PLAN-MXF
            \(MXFEncoder.encode(plan))
            """

            let architectTask = AtomicTask(targetFile: ".", action: "architect-plan", mxfContext: shard)
            let architectResult = try await dispatch(type: .architect, task: architectTask, correlation: correlation)
            results.append(architectResult)

            if let output = architectResult.output {
                let planGate = verifier.verifyPlan(action: output)
                if planGate.passed, let refreshed = try? MXFDecoder.decodeExecutionPlan(output.code) {
                    plan = refreshed
                }
            }
        }

        for step in plan.steps {
            let atomic = try ExecutionDirectiveCodec.atomicTask(from: step)

            let executorType = Self.executor(for: atomic, pipeline: pipeline)
            let outcome = try await dispatch(type: executorType, task: atomic, correlation: correlation)
            results.append(outcome)

            if let payload = outcome.output {
                let verdict = verifier.verify(action: payload)
                if verdict.passed == false {
                    try await snapshotManager.restore(snapshot: snapshot)
                    let explanation = verdict.violations.map(\.message).joined(separator: "; ")
                    throw MainAgentError.verificationFailed(message: explanation)
                }
            }
        }

        if pipeline.contains(.i18n) {
            let bundleTask = try Self.makeI18nTask(plan: plan, userTask: task)
            let outcome = try await dispatch(type: .i18n, task: bundleTask, correlation: correlation)
            results.append(outcome)

            if let payload = outcome.output {
                let verdict = verifier.verify(action: payload)
                if verdict.passed == false {
                    try await snapshotManager.restore(snapshot: snapshot)
                    let explanation = verdict.violations.map(\.message).joined(separator: "; ")
                    throw MainAgentError.verificationFailed(message: explanation)
                }
            }
        }

        if pipeline.contains(.test) {
            let harnessTask = try Self.makeHarnessTask(plan: plan, userTask: task)
            let outcome = try await dispatch(type: .test, task: harnessTask, correlation: correlation)
            results.append(outcome)

            if let payload = outcome.output {
                let verdict = verifier.verify(action: payload)
                if verdict.passed == false {
                    try await snapshotManager.restore(snapshot: snapshot)
                    let explanation = verdict.violations.map(\.message).joined(separator: "; ")
                    throw MainAgentError.verificationFailed(message: explanation)
                }
            }
        }

        return aggregator.aggregate(results: results)
    }

    private func dispatch(type: AgentType, task: AtomicTask, correlation: UUID) async throws -> AgentResult {
        let worker = try await agentPool.acquire(type: type, modelClient: modelClient)
        let outcome: AgentResult
        do {
            outcome = try await worker.execute(task: task)
        } catch {
            await agentPool.release(worker)
            throw error
        }
        await agentPool.release(worker)
        await emitProgress(correlation: correlation, agent: worker, outcome: outcome)
        return outcome
    }

    private func emitProgress(correlation: UUID, agent: any BaseAgent, outcome: AgentResult) async {
        let payload = """
        PROGRESS \(agent.type.rawValue)
        STATUS \(outcome.status.rawValue)
        TOKENS \(outcome.tokensUsed)
        TARGET \(outcome.task.targetFile)
        """

        let envelope = AgentMessage(
            id: UUID(),
            from: agent.id,
            to: "mnemox.bus",
            kind: .progressUpdate,
            payload: payload,
            timestamp: Date(),
            correlationID: correlation,
        )

        await messageBus.send(envelope)
    }

    private static func bootstrapScanTask(for plan: ExecutionPlan) -> AtomicTask {
        guard let head = plan.steps.first,
              let atomic = try? ExecutionDirectiveCodec.atomicTask(from: head) else {
            return AtomicTask(targetFile: ".", action: "scan-repository", mxfContext: "GRAPH EMPTY")
        }

        return AtomicTask(
            targetFile: atomic.targetFile,
            action: "scan-repository",
            mxfContext: atomic.mxfContext,
        )
    }

    private static func executor(for atomic: AtomicTask, pipeline: [AgentType]) -> AgentType {
        let lowered = atomic.action.lowercased()
        if pipeline.contains(.refactor), lowered.contains("refactor") {
            return .refactor
        }
        return .writer
    }

    private static func makeI18nTask(plan: ExecutionPlan, userTask: UserTask) throws -> AtomicTask {
        guard let head = plan.steps.first else {
            return AtomicTask(targetFile: "locales/en.json", action: "i18n-sync", mxfContext: userTask.detail)
        }

        let atomic = try ExecutionDirectiveCodec.atomicTask(from: head)
        let shard = """
        \(userTask.detail)

        \(atomic.mxfContext)
        """

        return AtomicTask(targetFile: atomic.targetFile, action: "i18n-sync", mxfContext: shard)
    }

    private static func makeHarnessTask(plan: ExecutionPlan, userTask: UserTask) throws -> AtomicTask {
        guard let head = plan.steps.first else {
            return AtomicTask(targetFile: ".", action: "emit-tests", mxfContext: userTask.detail)
        }

        let atomic = try ExecutionDirectiveCodec.atomicTask(from: head)
        let shard = """
        \(userTask.detail)

        \(atomic.mxfContext)
        """

        return AtomicTask(targetFile: atomic.targetFile, action: "emit-tests", mxfContext: shard)
    }
}

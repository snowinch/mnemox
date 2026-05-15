import Foundation

/// Vertical specialists coordinated by [`MainAgent`].
public enum AgentType: String, Sendable, Codable, CaseIterable {
    case scanner
    case architect
    case writer
    case refactor
    case i18n
    case test
    case verifier
}

/// Lifecycle outcome recorded for telemetry and aggregation.
public enum AgentStatus: String, Sendable, Codable {
    case success
    case failed
    case blocked
    case skipped
}

/// Structured executor payload surfaced to [`ResultAggregator`].
public struct AgentResult: Sendable, Equatable {
    public let agentID: AgentID
    public let task: AtomicTask
    public let output: ActionResult?
    public let mxfLog: [String]
    public let tokensUsed: Int
    public let durationMs: Int
    public let status: AgentStatus

    public init(
        agentID: AgentID,
        task: AtomicTask,
        output: ActionResult?,
        mxfLog: [String],
        tokensUsed: Int,
        durationMs: Int,
        status: AgentStatus,
    ) {
        self.agentID = agentID
        self.task = task
        self.output = output
        self.mxfLog = mxfLog
        self.tokensUsed = tokensUsed
        self.durationMs = durationMs
        self.status = status
    }
}

/// Uniform contract for deterministic Mnemox workers.
public protocol BaseAgent: Sendable {
    var id: AgentID { get }
    var type: AgentType { get }

    func execute(task: AtomicTask) async throws -> AgentResult
}

extension AgentType {
    /// Agents that multiplex the shared [`ModelClient`] slot (exclusive access enforced by [`AgentPool`]).
    var requiresExclusiveModelLease: Bool {
        switch self {
        case .scanner, .verifier:
            return false
        case .architect, .writer, .refactor, .i18n, .test:
            return true
        }
    }
}

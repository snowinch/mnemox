import Foundation

// Identifier used on MessageBus envelopes to route MXF payloads between deterministic agents.
public typealias AgentID = String

// Enumerates Mnemox message kinds flowing through orchestration before natural-language UX rendering.
public enum MessageType: String, Codable, CaseIterable, Sendable {
    case taskAssignment
    case contextRequest
    case contextResponse
    case progressUpdate
    case resultReady
    case blockingQuestion
    case conventionViolation
    case error
}

/// Inter-agent mailbox record encoded as MXF for zero-prose transports.
public struct AgentMessage: Codable, Equatable, Sendable {
    public var id: UUID
    public var from: AgentID
    public var to: AgentID
    public var kind: MessageType
    /// Secondary MXF document carried by this envelope (plans, deltas, verifier output, etc.).
    public var payload: String
    public var timestamp: Date
    public var correlationID: UUID?

    public init(
        id: UUID,
        from: AgentID,
        to: AgentID,
        kind: MessageType,
        payload: String,
        timestamp: Date,
        correlationID: UUID? = nil
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.kind = kind
        self.payload = payload
        self.timestamp = timestamp
        self.correlationID = correlationID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case from
        case to
        case kind = "type"
        case payload
        case timestamp
        case correlationID
    }

    /// Produces deterministic MXF for MessageBus payloads while preserving archival JSON encoding.
    public func encodeToMXF() -> String {
        MXFEncoder.encode(self)
    }
}

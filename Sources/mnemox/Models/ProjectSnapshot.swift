import Foundation

/// Captures hashed files, plans, and MXF transcripts for rewindable execution checkpoints.
public struct ProjectSnapshot: Codable, Equatable, Sendable {
    public struct FileSnapshot: Codable, Equatable, Sendable {
        public var relativePath: String
        public var sha256: String

        public init(relativePath: String, sha256: String) {
            self.relativePath = relativePath
            self.sha256 = sha256
        }
    }

    public var id: String
    public var timestamp: Date
    public var files: [FileSnapshot]
    public var agentPlan: ExecutionPlan
    public var mxfLog: [String]

    public init(
        id: String,
        timestamp: Date,
        files: [FileSnapshot],
        agentPlan: ExecutionPlan,
        mxfLog: [String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.files = files
        self.agentPlan = agentPlan
        self.mxfLog = mxfLog
    }

    /// Serializes the snapshot plan leg into MXF while leaving auxiliary metadata JSON-native.
    public func encodePlanToMXF() -> String {
        MXFEncoder.encode(agentPlan)
    }
}

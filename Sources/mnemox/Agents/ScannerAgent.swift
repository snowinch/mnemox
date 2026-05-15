import Foundation

/// Repository ingest specialist emitting MXF snapshots without touching [`ModelClient`].
public struct ScannerAgent: BaseAgent {
    public let id: AgentID
    public let type: AgentType = .scanner

    private let root: URL
    private let graph: DependencyGraph

    public init(id: AgentID, root: URL, graph: DependencyGraph) {
        self.id = id
        self.root = root
        self.graph = graph
    }

    public func execute(task: AtomicTask) async throws -> AgentResult {
        let started = Date()
        var log: [String] = []

        let scanner = ProjectScanner()
        let snapshot = try await scanner.scan(root: root)
        log.append(contentsOf: snapshot.mxfLog)

        let cappedPaths = graph.trackedRelativePaths.prefix(48)
        for relative in cappedPaths {
            guard let record = graph.dependencyRecord(for: relative) else {
                continue
            }
            log.append(MXFEncoder.encode(record))
        }

        let targetURL = root.appendingPathComponent(task.targetFile)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            log.append(graph.impactOf(changing: targetURL).encodeToMXF())
        }

        log.insert("SCAN/TARGET \(task.targetFile) ACT \(task.action)", at: 0)

        let envelope = AgentMessage(
            id: UUID(),
            from: id,
            to: "mnemox.main",
            kind: .resultReady,
            payload: MXFEncoder.encode(snapshot.agentPlan),
            timestamp: Date(),
            correlationID: nil,
        )
        log.append(MXFEncoder.encode(envelope))

        let elapsed = Self.ms(from: started)
        return AgentResult(
            agentID: id,
            task: task,
            output: nil,
            mxfLog: log,
            tokensUsed: 0,
            durationMs: elapsed,
            status: .success,
        )
    }

    private static func ms(from start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }
}

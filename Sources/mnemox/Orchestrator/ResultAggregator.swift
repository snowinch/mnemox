import Foundation

/// Disk-facing mutation envelope aggregated for UX approval.
public enum ChangeType: String, Sendable, Codable {
    case create
    case modify
    case delete
}

/// Concrete filesystem mutation surfaced to SwiftUI reviewers.
public struct FileChange: Sendable, Equatable {
    public let path: URL
    public let originalContent: String?
    public let newContent: String
    public let changeType: ChangeType

    public init(path: URL, originalContent: String?, newContent: String, changeType: ChangeType) {
        self.path = path
        self.originalContent = originalContent
        self.newContent = newContent
        self.changeType = changeType
    }
}

/// Merge-ready orchestration capsule handed back to [`MnemoxApp`].
public struct AggregatedResult: Sendable, Equatable {
    public let fileChanges: [FileChange]
    public let summary: String
    public let totalTokensUsed: Int
    public let mxfLog: [String]
    public let requiresUserApproval: Bool

    public init(
        fileChanges: [FileChange],
        summary: String,
        totalTokensUsed: Int,
        mxfLog: [String],
        requiresUserApproval: Bool,
    ) {
        self.fileChanges = fileChanges
        self.summary = summary
        self.totalTokensUsed = totalTokensUsed
        self.mxfLog = mxfLog
        self.requiresUserApproval = requiresUserApproval
    }
}

/// Deterministic reducer merging executor telemetry before UX narration.
public struct ResultAggregator: Sendable {
    public init() {}

    public func aggregate(results: [AgentResult]) -> AggregatedResult {
        let tokens = results.reduce(0) { partial, row in
            partial + row.tokensUsed
        }

        let mergedLog = results.flatMap(\.mxfLog)

        var changes: [FileChange] = []
        for row in results {
            guard let output = row.output else {
                continue
            }

            let relative = output.targetFile ?? row.task.targetFile
            let destination = URL(fileURLWithPath: relative, isDirectory: false)

            guard output.code.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false else {
                continue
            }

            changes.append(
                FileChange(
                    path: destination,
                    originalContent: nil,
                    newContent: output.code,
                    changeType: .modify,
                ),
            )
        }

        let summaryBody = changes.map(\.path.lastPathComponent).joined(separator: ", ")
        let summary =
            changes.isEmpty
                ? "No file mutations were emitted by executor agents."
                : "Prepared updates for \(changes.count) path(s): \(summaryBody)."

        let requiresApproval = changes.isEmpty == false

        return AggregatedResult(
            fileChanges: changes,
            summary: summary,
            totalTokensUsed: tokens,
            mxfLog: mergedLog,
            requiresUserApproval: requiresApproval,
        )
    }
}

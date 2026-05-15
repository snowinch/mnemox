import Foundation

/// Natural-language goal handed from the UI before orchestration shards it.
public struct UserTask: Sendable, Equatable, Codable {
    public var title: String
    public var detail: String
    public var parameters: [String: String]

    public init(title: String = "", detail: String, parameters: [String: String] = [:]) {
        self.title = title
        self.detail = detail
        self.parameters = parameters
    }
}

/// Single-file executor instruction emitted by [`TaskDecomposer`].
public struct AtomicTask: Sendable, Equatable, Codable {
    public var targetFile: String
    public var action: String
    public var mxfContext: String

    public init(targetFile: String, action: String, mxfContext: String) {
        self.targetFile = targetFile
        self.action = action
        self.mxfContext = mxfContext
    }
}

/// Ordered gate invoked before model-backed agents run.
public enum PreFlightCheck: String, Sendable, Codable, Equatable, CaseIterable {
    case ambiguityGuard
    case i18nGuard
    case duplicationGuard
    case breakingChangeGuard
    case scopeGuard
}

/// Outcome bundle for [`PreFlightSystem.run`].
public struct PreFlightResult: Sendable, Equatable {
    public var passed: Bool
    public var blockingCheck: PreFlightCheck?
    public var warnings: [PreFlightCheck]
    public var question: String?

    public init(passed: Bool, blockingCheck: PreFlightCheck?, warnings: [PreFlightCheck], question: String?) {
        self.passed = passed
        self.blockingCheck = blockingCheck
        self.warnings = warnings
        self.question = question
    }
}

/// Concrete edit hypothesis feeding [`ImpactAnalyzer`].
public enum ProposedChange: Sendable, Equatable {
    case fileMove(from: URL, to: URL)
    case symbolRename(name: String, file: URL)
    case propsModified(component: String, file: URL)
    case fileDelete(at: URL)
}

/// Shared failure modes for repository intelligence components.
public enum CoreIntelligenceError: Error, Sendable, Equatable {
    case missingRoot(URL)
    case unreadableFile(URL)
    case invalidManifest(URL)
}

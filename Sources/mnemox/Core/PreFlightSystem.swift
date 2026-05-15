import Foundation

/// Phase 1 orchestrator gates mirroring the five Mnemox pre-flight checks.
public struct PreFlightSystem: Sendable {
    public init() {}

    public func run(task: UserTask, graph: DependencyGraph, conventions: ConventionProfile) async throws -> PreFlightResult {
        var warnings: [PreFlightCheck] = []

        if let question = Self.ambiguityQuestion(for: task) {
            return PreFlightResult(passed: false, blockingCheck: .ambiguityGuard, warnings: warnings, question: question)
        }

        if let question = Self.i18nQuestion(for: task, conventions: conventions) {
            return PreFlightResult(passed: false, blockingCheck: .i18nGuard, warnings: warnings, question: question)
        }

        if Self.duplicationWarning(for: task, graph: graph) {
            warnings.append(.duplicationGuard)
        }

        if Self.breakingChangeWarning(for: task, graph: graph) {
            warnings.append(.breakingChangeGuard)
        }

        if let question = Self.scopeQuestion(for: task) {
            return PreFlightResult(passed: false, blockingCheck: .scopeGuard, warnings: warnings, question: question)
        }

        return PreFlightResult(passed: true, blockingCheck: nil, warnings: warnings, question: nil)
    }

    private static func ambiguityQuestion(for task: UserTask) -> String? {
        let haystack = task.detail.lowercased()
        guard haystack.contains("component") || haystack.contains("hero") else {
            return nil
        }

        let requiredKeys = ["title", "subtitle"]
        let missing = requiredKeys.filter { key in
            task.parameters.keys.contains(where: { $0.lowercased() == key }) == false
        }

        guard missing.isEmpty == false else {
            return nil
        }

        return "Specify \(missing.joined(separator: ", ")) parameters before modifying UI components."
    }

    private static func i18nQuestion(for task: UserTask, conventions: ConventionProfile) -> String? {
        let wire = conventions.encodeToMXF().lowercased()
        guard wire.contains("i18n"), wire.contains("required") else {
            return nil
        }

        guard task.detail.range(of: #"["'][^"']{3,}["']"#, options: .regularExpression) != nil else {
            return nil
        }

        return "This repository enforces i18n. Replace hard-coded UI strings with locale keys before continuing."
    }

    private static func duplicationWarning(for task: UserTask, graph: DependencyGraph) -> Bool {
        guard let candidate = firstPathToken(from: task.detail) else {
            return false
        }
        return graph.trackedRelativePaths.contains { $0.hasSuffix(candidate) }
    }

    private static func breakingChangeWarning(for task: UserTask, graph: DependencyGraph) -> Bool {
        let detail = task.detail.lowercased()
        guard detail.contains("rename") || detail.contains("props") else {
            return false
        }
        return graph.trackedRelativePaths.count > 3
    }

    private static func scopeQuestion(for task: UserTask) -> String? {
        let clauses = task.detail.split(separator: ";").filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
        guard clauses.count >= 4 else {
            return nil
        }
        return "Task spans \(clauses.count) sequential clauses. Confirm decomposition order before execution."
    }

    private static func firstPathToken(from detail: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"[\w\-]+(?:/[\w\-]+)+\.(?:ts|tsx|js|jsx|vue|swift|py)"#,
            options: [],
        ) else {
            return nil
        }

        let range = NSRange(detail.startIndex ..< detail.endIndex, in: detail)
        guard let match = regex.firstMatch(in: detail, options: [], range: range),
              let swiftRange = Range(match.range, in: detail) else {
            return nil
        }

        let token = String(detail[swiftRange])
        return (token as NSString).lastPathComponent
    }
}

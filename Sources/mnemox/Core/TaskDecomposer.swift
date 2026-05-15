import Foundation

/// Converts sprawling intents into MXF-serializable execution ladders with dependency-safe ordering.
public struct TaskDecomposer: Sendable {
    public init() {}

    public func decompose(task: UserTask, graph: DependencyGraph, conventions: ConventionProfile) async throws -> ExecutionPlan {
        let targets = Self.resolveTargets(for: task, graph: graph)
        let ordered = graph.topologicalOrdering(of: targets)

        var steps: [ExecutionPlan.Step] = []
        for (index, relative) in ordered.enumerated() {
            let dependencyMXF = graph.dependencyRecord(for: relative).map { MXFEncoder.encode($0) } ?? "#\(relative)"
            let mergedContext = dependencyMXF + "\n" + conventions.encodeToMXF()
            let clipped = Self.clipContext(mergedContext, maxTokens: 300)
            let atomic = AtomicTask(targetFile: relative, action: Self.actionVerb(for: task.detail), mxfContext: clipped)
            let directive = Self.encodeAtomicTask(atomic)
            steps.append(
                ExecutionPlan.Step(number: index + 1, agentCode: "WRITE", directive: directive),
            )
        }

        let slug = Self.slug(from: task.detail)
        return ExecutionPlan(action: slug, target: "task-scope", steps: steps)
    }

    private static func resolveTargets(for task: UserTask, graph: DependencyGraph) -> [String] {
        let tokens = pathTokens(in: task.detail)
        let tracked = graph.trackedRelativePaths
        let hits = tracked.filter { path in tokens.contains(where: { token in path.hasSuffix(token) }) }
        if hits.isEmpty == false {
            return Array(Set(hits)).sorted()
        }
        return Array(tracked.prefix(5))
    }

    private static func pathTokens(in detail: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"[\w\-]+(?:/[\w\-]+)+\.(?:ts|tsx|js|jsx|vue|swift|py)"#,
            options: [],
        ) else {
            return []
        }

        let range = NSRange(detail.startIndex ..< detail.endIndex, in: detail)
        return regex.matches(in: detail, options: [], range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: detail) else {
                return nil
            }
            return String(detail[swiftRange])
        }
    }

    private static func actionVerb(for detail: String) -> String {
        let lower = detail.lowercased()
        if lower.contains("rename") {
            return "rename-symbol"
        }
        if lower.contains("delete") || lower.contains("remove") {
            return "delete-file"
        }
        return "update-file"
    }

    private static func slug(from detail: String) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let bounded = trimmed.prefix(48)
        let sanitized = bounded.reduce(into: "") { partialResult, character in
            if character.isLetter || character.isNumber || character == "-" {
                partialResult.append(character)
            } else {
                partialResult.append("-")
            }
        }
        var collapsed = sanitized
        while collapsed.contains("--") {
            collapsed = collapsed.replacingOccurrences(of: "--", with: "-")
        }
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func encodeAtomicTask(_ task: AtomicTask) -> String {
        guard let data = try? JSONEncoder().encode(task),
              let json = String(data: data, encoding: .utf8) else {
            return "#\(task.targetFile) \(task.action)\n\(task.mxfContext)"
        }
        return json
    }

    private static func clipContext(_ value: String, maxTokens: Int) -> String {
        guard MXFTokenCounter.count(value) > maxTokens else {
            return value
        }

        var end = value.endIndex
        while end > value.startIndex {
            end = value.index(before: end)
            let slice = String(value[..<end])
            if MXFTokenCounter.count(slice) <= maxTokens {
                return slice
            }
        }
        return ""
    }
}

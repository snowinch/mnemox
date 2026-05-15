import Foundation

/// Assembles deterministic [`ModelPrompt`] envelopes that honor Mnemox’ MXF token budgets ahead of executor dispatch.
public enum PromptEngine {
    static let systemTokenCeiling = 50
    static let contextTokenCeiling = 300
    static let atomicTaskTokenCeiling = 50
    static let cumulativePromptCeiling = 400
    static let outputContractCeiling = 40

    public static func build(
        task: AtomicTask,
        conventions: ConventionProfile,
        context dependencies: [FileDependency],
    ) throws -> ModelPrompt {
        let (temperature, maxTokens) = resolveGenerationProfile(forAction: task.action)
        let languageHint = inferLanguageTag(fromRelativePath: task.targetFile)

        let rawSystem = assembleSystemBanner(conventions: conventions)
        let rawContext = assembleContextMXF(for: dependencies, task: task)
        let rawTask = assembleAtomicTaskWire(task)
        let rawContract = assembleOutputContract(language: languageHint, relativePath: task.targetFile)

        let composed = fitAggregate(
            rawSystem: rawSystem,
            rawContext: rawContext,
            rawTask: rawTask,
            rawContract: rawContract,
            temperature: temperature,
            maxTokens: maxTokens,
        )

        try assertBudgetCompliance(composed)
        return composed
    }

    public static func cumulativeTokenEstimate(for prompt: ModelPrompt) -> Int {
        MXFTokenCounter.count(prompt.system)
            + MXFTokenCounter.count(prompt.context)
            + MXFTokenCounter.count(prompt.task)
            + MXFTokenCounter.count(prompt.outputContract)
    }

    // MARK: - Internals

    private static func assembleSystemBanner(conventions: ConventionProfile) -> String {
        let profile = conventions.encodeToMXF()
        if profile.isEmpty {
            return """
            Code executor. Produce only compilable artifacts. Obey Mnemox MXF overlays.
            """
        }

        return """
        Code executor. Produce only compilable artifacts. Obey Mnemox MXF overlays.

        MXF PROFILE
        \(profile)
        """
    }

    private static func assembleContextMXF(for dependencies: [FileDependency], task: AtomicTask) -> String {
        guard dependencies.isEmpty == false else {
            return fallbackContext(for: task)
        }

        var ordered = prioritizedDependencies(dependencies, primaryPath: task.targetFile)

        func joined(_ deps: [FileDependency]) -> String {
            deps.map { MXFEncoder.encode($0) }.joined(separator: "\n\n")
        }

        while ordered.count > 1 && MXFTokenCounter.count(joined(ordered)) > contextTokenCeiling {
            ordered.removeLast()
        }

        var clipped = clipTail(joined(ordered), maxTokens: contextTokenCeiling)

        if clipped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clipped = fallbackContext(for: task)
        }

        return clipped
    }

    private static func prioritizedDependencies(_ dependencies: [FileDependency], primaryPath: String)
        -> [FileDependency]
    {
        dependencies
            .sorted { lhs, rhs in
                relevanceScore(lhs, primaryPath: primaryPath) < relevanceScore(rhs, primaryPath: primaryPath)
            }
            .reversed()
    }

    private static func relevanceScore(_ dependency: FileDependency, primaryPath: String) -> Int {
        let normalizedPrimary = normalizePathFragment(primaryPath)
        let normalizedPath = normalizePathFragment(dependency.path)

        let primaryMatch = normalizedPath == normalizedPrimary ? 4096 : 0
        let symbolWeight = dependency.imports.reduce(0) { partial, fragment in partial + fragment.symbols.count }
        let autoWeight = dependency.autoSymbols.count * 3
        let templateWeight = dependency.templateComponents.count * 6

        return primaryMatch + symbolWeight + autoWeight + templateWeight
    }

    private static func normalizePathFragment(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "\\", with: "/")
    }

    private static func fallbackContext(for task: AtomicTask) -> String {
        clipTail(task.mxfContext, maxTokens: contextTokenCeiling)
    }

    private static func assembleAtomicTaskWire(_ task: AtomicTask) -> String {
        """
        TASK \(task.action) #\(task.targetFile)

        CONTEXT-SHARD
        \(task.mxfContext)
        """
    }

    private static func assembleOutputContract(language: String, relativePath: String) -> String {
        """
        OUT:code-only lang:\(language) path:#\(relativePath)
        forbid:markdown forbid:explainer forbid:triple-backticks
        """
    }

    private static func inferLanguageTag(fromRelativePath relativePath: String) -> String {
        let lowercase = relativePath.lowercased()
        if lowercase.hasSuffix(".swift") { return "swift" }
        if lowercase.hasSuffix(".ts") || lowercase.hasSuffix(".tsx") { return "typescript" }
        if lowercase.hasSuffix(".js") || lowercase.hasSuffix(".jsx") { return "javascript" }
        if lowercase.hasSuffix(".vue") { return "vue" }
        if lowercase.hasSuffix(".py") { return "python" }
        return "plaintext"
    }

    private static func resolveGenerationProfile(forAction action: String) -> (Double, Int) {
        let normalized = action.lowercased()

        if normalized.contains("rename") {
            return (0.1, 100)
        }
        if normalized.contains("prop") {
            return (0.1, 150)
        }
        if normalized.contains("component") || normalized.contains("generate") || normalized.contains("create") {
            return (0.3, 500)
        }
        return (0.1, 200)
    }

    private static func fitAggregate(
        rawSystem: String,
        rawContext: String,
        rawTask: String,
        rawContract: String,
        temperature: Double,
        maxTokens: Int,
    ) -> ModelPrompt {
        var systemCap = systemTokenCeiling
        var contextCap = contextTokenCeiling
        var taskCap = atomicTaskTokenCeiling
        var contractCap = outputContractCeiling

        func pack() -> ModelPrompt {
            ModelPrompt(
                system: clipTail(rawSystem, maxTokens: systemCap),
                context: clipTail(rawContext, maxTokens: contextCap),
                task: clipTail(rawTask, maxTokens: taskCap),
                outputContract: clipTail(rawContract, maxTokens: contractCap),
                temperature: temperature,
                maxTokens: maxTokens,
            )
        }

        var draft = pack()
        var iterations = 0

        while cumulativeTokenEstimate(for: draft) > cumulativePromptCeiling && iterations < 4096 {
            iterations += 1

            if contextCap > 0 {
                contextCap -= 1
            } else if taskCap > 0 {
                taskCap -= 1
            } else if systemCap > 0 {
                systemCap -= 1
            } else if contractCap > 0 {
                contractCap -= 1
            } else {
                return ModelPrompt(
                    system: "",
                    context: "",
                    task: "",
                    outputContract: "",
                    temperature: temperature,
                    maxTokens: maxTokens,
                )
            }

            draft = pack()
        }

        return draft
    }

    private static func clipTail(_ value: String, maxTokens: Int) -> String {
        guard maxTokens > 0 else {
            return ""
        }

        guard MXFTokenCounter.count(value) > maxTokens else {
            return value
        }

        var endIndex = value.endIndex
        while endIndex > value.startIndex {
            endIndex = value.index(before: endIndex)
            let candidate = String(value[..<endIndex]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if MXFTokenCounter.count(candidate) <= maxTokens {
                return candidate
            }
        }

        return ""
    }

    private static func assertBudgetCompliance(_ prompt: ModelPrompt) throws {
        guard MXFTokenCounter.count(prompt.system) <= systemTokenCeiling else {
            throw ModelError.tokenLimitExceeded
        }

        guard MXFTokenCounter.count(prompt.context) <= contextTokenCeiling else {
            throw ModelError.tokenLimitExceeded
        }

        guard MXFTokenCounter.count(prompt.task) <= atomicTaskTokenCeiling else {
            throw ModelError.tokenLimitExceeded
        }

        guard MXFTokenCounter.count(prompt.outputContract) <= outputContractCeiling else {
            throw ModelError.tokenLimitExceeded
        }

        guard cumulativeTokenEstimate(for: prompt) <= cumulativePromptCeiling else {
            throw ModelError.tokenLimitExceeded
        }
    }
}

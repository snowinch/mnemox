import Foundation

/// Declares downstream expectations enforced while normalizing streamed assistant payloads.
public struct OutputContract: Sendable, Equatable {
    /// ISO language slug such as `swift` or `typescript`.
    public var language: String
    /// Optional repository-relative path hinted by PromptEngine overlays.
    public var targetFile: String?
    /// Short guardrail reminding executors what shape is permissible.
    public var shapeDirective: String

    public init(language: String, targetFile: String? = nil, shapeDirective: String = "structured_code_only") {
        self.language = language
        self.targetFile = targetFile
        self.shapeDirective = shapeDirective
    }
}

/// Actionable payload reconstructed from a [`ModelResponse`].
public struct ActionResult: Sendable, Equatable {
    /// Extracted imperative source sans markdown scaffolding.
    public let code: String
    /// Language slug inherited from [`OutputContract`].
    public let language: String
    /// Best-effort file destination from [`OutputContract`].
    public let targetFile: String?
    /// False when truncation or transport errors signaled incompleteness.
    public let isComplete: Bool
    /// Lightweight diagnostics surfaced to orchestrator auditors.
    public let validationHints: [String]

    public init(code: String, language: String, targetFile: String?, isComplete: Bool, validationHints: [String]) {
        self.code = code
        self.language = language
        self.targetFile = targetFile
        self.isComplete = isComplete
        self.validationHints = validationHints
    }
}

/// Normalizes multilingual assistant payloads into deterministic [`ActionResult`] bundles.
public enum ResponseParser {

    /// Converts a [`ModelResponse`] into an [`ActionResult`], rejecting vacuous completions.
    public static func parse(_ response: ModelResponse, expected: OutputContract) throws -> ActionResult {
        var hints: [String] = []
        let normalized = stripMarkdownFences(in: response.content, hints: &hints)
        let trimmed = normalized.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        switch response.finishReason {
        case .length:
            hints.append("finish-reason-length")
        case .error:
            hints.append("finish-reason-error")
        case .stop:
            break
        }

        if response.finishReason == .stop && trimmed.isEmpty {
            throw ModelError.invalidResponse("Model returned only whitespace after markdown stripping.")
        }

        let isComplete = response.finishReason == .stop

        if trimmed.isEmpty {
            return ActionResult(
                code: "",
                language: expected.language,
                targetFile: expected.targetFile,
                isComplete: false,
                validationHints: hints,
            )
        }

        if isComplete {
            hints.append(contractHint(for: expected))
        }

        return ActionResult(
            code: trimmed,
            language: expected.language,
            targetFile: expected.targetFile,
            isComplete: isComplete,
            validationHints: hints,
        )
    }

    // MARK: - Internals

    private static func contractHint(for contract: OutputContract) -> String {
        if let path = contract.targetFile {
            return "contract:lang=\(contract.language) path=\(path) shape=\(contract.shapeDirective)"
        }

        return "contract:lang=\(contract.language) shape=\(contract.shapeDirective)"
    }

    private static func stripMarkdownFences(in raw: String, hints: inout [String]) -> String {
        let marker = "```"
        guard raw.contains(marker) else {
            return raw
        }

        var capturing = false
        var buffer: [Substring] = []
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix(marker) {
                hints.append("stripped-fence")
                capturing.toggle()
                continue
            }

            if capturing {
                buffer.append(line)
            }
        }

        if capturing {
            hints.append("unterminated-fence")
        }

        let merged = buffer.joined(separator: "\n")
        if merged.isEmpty {
            return raw.replacingOccurrences(of: marker, with: "")
        }

        return String(merged)
    }
}

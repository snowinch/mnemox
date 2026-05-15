import Foundation

/// Deterministic QA specialist validating executor payloads without invoking [`ModelClient`].
public struct VerificationViolation: Sendable, Equatable {
    public let location: String
    public let message: String

    public init(location: String, message: String) {
        self.location = location
        self.message = message
    }
}

/// Structured QA verdict referencing MXF-safe coordinates rather than prose paragraphs.
public struct VerificationResult: Sendable, Equatable {
    public let passed: Bool
    public let violations: [VerificationViolation]

    public init(passed: Bool, violations: [VerificationViolation]) {
        self.passed = passed
        self.violations = violations
    }
}

/// Executes offline lint-equivalent gates mirroring Mnemox verifier doctrine.
public struct VerifierAgent: BaseAgent {
    public let id: AgentID
    public let type: AgentType = .verifier

    private let conventions: ConventionProfile

    public init(id: AgentID, conventions: ConventionProfile) {
        self.id = id
        self.conventions = conventions
    }

    public func execute(task: AtomicTask) async throws -> AgentResult {
        let started = Date()
        let synthetic = ActionResult(
            code: task.mxfContext,
            language: "plaintext",
            targetFile: task.targetFile,
            isComplete: true,
            validationHints: [],
        )

        let verdict = verify(action: synthetic)
        let elapsed = Self.ms(from: started)

        var log = ["VERIFY/EXECUTE-MODE \(verdict.passed ? "PASS" : "FAIL")"]
        log.append(contentsOf: verdict.violations.map { violation in
            "VERIFY/\(violation.location) \(violation.message)"
        })

        let status: AgentStatus = verdict.passed ? .skipped : .failed

        return AgentResult(
            agentID: id,
            task: task,
            output: verdict.passed ? nil : synthetic,
            mxfLog: log,
            tokensUsed: 0,
            durationMs: elapsed,
            status: status,
        )
    }

    /// Runs deterministic QA gates suitable immediately after [`ModelClient`] completions.
    public func verify(action: ActionResult) -> VerificationResult {
        var violations: [VerificationViolation] = []

        let code = action.code.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if code.isEmpty {
            violations.append(
                VerificationViolation(location: "body", message: "Generated artifact was empty."),
            )
        }

        if code.contains("```") {
            violations.append(
                VerificationViolation(location: "fence", message: "Markdown fences cannot ship to disk."),
            )
        }

        if action.isComplete == false {
            violations.append(
                VerificationViolation(location: "finish", message: "finish_reason must stop before merging."),
            )
        }

        if action.validationHints.contains("finish-reason-length") || action.validationHints.contains("finish-reason-error") {
            violations.append(
                VerificationViolation(location: "finish", message: "Model ended generation prematurely."),
            )
        }

        let profileWire = conventions.encodeToMXF().lowercased()
        if profileWire.contains("i18n"), profileWire.contains("required") {
            if Self.includesSuspiciousQuotedUXCopy(code, language: action.language) {
                violations.append(
                    VerificationViolation(location: "i18n", message: "Hard-coded UX strings violate enforced localization."),
                )
            }
        }

        violations.append(contentsOf: Self.evaluateImports(code: code, language: action.language))

        return VerificationResult(passed: violations.isEmpty, violations: violations)
    }

    /// Validates architect ladder fragments separately from executable sources.
    public func verifyPlan(action: ActionResult) -> VerificationResult {
        let trimmed = action.code.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return VerificationResult(
                passed: false,
                violations: [VerificationViolation(location: "plan", message: "Architect emitted empty PLAN payload.")],
            )
        }

        do {
            _ = try MXFDecoder.decodeExecutionPlan(trimmed)
            return VerificationResult(passed: true, violations: [])
        } catch {
            return VerificationResult(
                passed: false,
                violations: [
                    VerificationViolation(location: "plan", message: "Architect MXF failed structural decoding."),
                ],
            )
        }
    }

    private static func ms(from start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    private static func evaluateImports(code: String, language: String) -> [VerificationViolation] {
        let lowered = language.lowercased()

        if lowered == "swift" {
            return evaluateSwiftImports(code)
        }

        if lowered == "typescript" || lowered == "javascript" || lowered == "vue" {
            return evaluateJSImports(code)
        }

        return []
    }

    private static func evaluateSwiftImports(_ code: String) -> [VerificationViolation] {
        let lines = code.split(separator: "\n")
        let swiftImport = try? NSRegularExpression(pattern: #"^\s*import\s+[A-Za-z0-9_.]+\s*$"#, options: [])

        var violations: [VerificationViolation] = []
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            guard trimmed.hasPrefix("import ") else {
                continue
            }

            let range = NSRange(trimmed.startIndex ..< trimmed.endIndex, in: trimmed)
            if let swiftImport, swiftImport.firstMatch(in: trimmed, options: [], range: range) == nil {
                violations.append(
                    VerificationViolation(location: "import:L\(idx + 1)", message: "Malformed Swift import syntax."),
                )
            }
        }

        return violations
    }

    private static func evaluateJSImports(_ code: String) -> [VerificationViolation] {
        let lines = code.split(separator: "\n")
        let jsImport = try? NSRegularExpression(
            pattern: #"^\s*import\s[\s\S]*?\sfrom\s['"][^'"]+['"];?$"#,
            options: [],
        )

        var violations: [VerificationViolation] = []
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            guard trimmed.hasPrefix("import ") else {
                continue
            }

            let range = NSRange(trimmed.startIndex ..< trimmed.endIndex, in: trimmed)
            if let jsImport, jsImport.firstMatch(in: trimmed, options: [], range: range) == nil {
                violations.append(
                    VerificationViolation(location: "import:L\(idx + 1)", message: "Malformed ES module import."),
                )
            }
        }

        return violations
    }

    private static func includesSuspiciousQuotedUXCopy(_ code: String, language: String) -> Bool {
        let lowered = language.lowercased()
        if lowered == "json" || lowered == "plaintext" {
            return false
        }

        guard let detector = try? NSRegularExpression(
            pattern: #"['"]([^'"\\]|\\.){4,}['"]"#,
            options: [],
        ) else {
            return false
        }

        let lines = code.split(separator: "\n")
        for line in lines {
            let textLine = String(line)
            let trimmed = textLine.trimmingCharacters(in: CharacterSet.whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("import ") || trimmed.hasPrefix("export ") {
                continue
            }

            let range = NSRange(textLine.startIndex ..< textLine.endIndex, in: textLine)
            if detector.firstMatch(in: textLine, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }
}

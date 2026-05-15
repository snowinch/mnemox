import Foundation

/// Summarizes blast-radius for a symbol edit before writers touch dependent files.
public struct ImpactReport: Codable, Equatable, Sendable {
    public struct FileImpact: Codable, Equatable, Sendable {
        public var path: String
        public var reason: String
        /// What kind of edit is required (import rewrite, rename reference, prop wiring, removal, etc.).
        public var updateType: String
        /// False when deterministic tooling can apply the change without model guidance.
        public var requiresModelIntervention: Bool

        public init(path: String, reason: String, updateType: String, requiresModelIntervention: Bool) {
            self.path = path
            self.reason = reason
            self.updateType = updateType
            self.requiresModelIntervention = requiresModelIntervention
        }
    }

    public var symbol: String
    public var changeType: String
    public var files: [FileImpact]

    public init(symbol: String, changeType: String, files: [FileImpact]) {
        self.symbol = symbol
        self.changeType = changeType
        self.files = files
    }

    /// Emits the canonical `IMPACT:` MXF block used in planning attachments.
    public func encodeToMXF() -> String {
        var lines: [String] = []
        lines.append("IMPACT:\(symbol) \(changeType)")
        for file in files {
            let reason = ImpactReport.escapeReasonFragment(file.reason)
            let updateType = ImpactReport.escapeReasonFragment(file.updateType)
            lines.append(
                "  \(file.path)[\(reason)] update:\(updateType) model:\(file.requiresModelIntervention ? "true" : "false")",
            )
        }
        return lines.joined(separator: "\n")
    }

    private static func escapeReasonFragment(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
    }
}

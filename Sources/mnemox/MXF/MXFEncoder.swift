import Foundation

/// Shared wire markers used across Mnemox Format serializers and parsers.
internal enum MXFTransmissionMarkers {
    internal static let payloadSeparatorLine = "<<<PAYLOAD>>>"
}

/// Canonical serializer turning typed Mnemox models into compact Mnemox Format wire text.
public enum MXFEncoder {
    public static func encode(_ file: FileDependency) -> String {
        let frameworkSuffix = encodeFrameworkSuffix(file.framework)
        var segments: [String] = []
        segments.append("#\(file.path)" + frameworkSuffix)

        file.imports.forEach { fragment in
            let payload = fragment.symbols.joined(separator: ",")
            segments.append("  <-\(fragment.modulePath)[\(payload)]")
        }

        if file.autoSymbols.isEmpty == false {
            segments.append("  auto[\(file.autoSymbols.joined(separator: ","))]")
        }

        if file.templateComponents.isEmpty == false {
            segments.append("  tmpl[\(file.templateComponents.joined(separator: ","))]")
        }

        return segments.joined(separator: "\n")
    }

    public static func encode(_ component: ComponentInterface) -> String {
        let frameworkSuffix = encodeFrameworkSuffix(component.framework)
        var segments: [String] = []
        segments.append("#\(component.path)" + frameworkSuffix)

        encodePropsBlock(component.props).map { segments.append($0) }
        component.relationalTargets.forEach { target in
            segments.append("  <-\(target)")
        }

        return segments.joined(separator: "\n")
    }

    public static func encode(_ plan: ExecutionPlan) -> String {
        var segments: [String] = []
        segments.append("PLAN:\(plan.action)/\(plan.target)")
        plan.steps.forEach { step in
            segments.append("  \(step.number):\(step.agentCode) \(step.directive)")
        }
        return segments.joined(separator: "\n")
    }

    public static func encode(_ conventions: ConventionProfile) -> String {
        let normalizedTags = conventions.frameworkTags.compactMap { normalizeConventionTagFragment($0) }
        let header = normalizedTags.joined(separator: " ")
        var segments: [String] = []
        if header.isEmpty == false {
            segments.append(header)
        }

        conventions.ruleLines.filter { $0.isEmpty == false }.forEach { segments.append($0) }

        guard segments.isEmpty == false else {
            return ""
        }

        return segments.joined(separator: "\n")
    }

    public static func encode(_ message: AgentMessage) -> String {
        var segments: [String] = []
        segments.append("MSG \(message.from)->\(message.to) \(message.kind.rawValue)")
        segments.append("id:\(message.id.uuidString.lowercased())")
        segments.append("ts:\(Iso8601Transport.string(from: message.timestamp))")
        if let corr = message.correlationID {
            segments.append("corr:\(corr.uuidString.lowercased())")
        }
        segments.append(MXFTransmissionMarkers.payloadSeparatorLine)
        segments.append(message.payload)
        return segments.joined(separator: "\n")
    }

    private static func normalizeConventionTagFragment(_ tag: String) -> String? {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        guard trimmed.hasPrefix("@") else {
            return "@\(trimmed)"
        }

        return trimmed
    }

    private static func encodeFrameworkSuffix(_ fragment: String?) -> String {
        guard let trimmed = fragment?.trimmingCharacters(in: .whitespacesAndNewlines), trimmed.isEmpty == false else {
            return ""
        }

        if trimmed.hasPrefix("@") {
            return " \(trimmed)"
        }

        return " @\(trimmed)"
    }

    private static func encodePropsBlock(_ props: [ComponentInterface.Prop]) -> String? {
        guard props.isEmpty == false else {
            return nil
        }

        let serialized = props.map { encodeSinglePropFragment($0) }.joined(separator: ", ")
        return "  props[\(serialized)]"
    }

    private static func encodeSinglePropFragment(_ fragment: ComponentInterface.Prop) -> String {
        let modifier = fragment.optionality == .required ? "!" : "?"
        var output = "\(fragment.name)\(modifier):\(fragment.abbreviatedType)"
        fragment.defaultValue.map { value in
            output += " default=\(value)"
        }
        return output
    }
}

private enum Iso8601Transport {
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let coarseFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(from date: Date) -> String {
        let fractional = fractionalFormatter.string(from: date)
        if fractional.isEmpty == false {
            return fractional
        }

        let coarse = coarseFormatter.string(from: date)
        if coarse.isEmpty == false {
            return coarse
        }

        let epochMillis = Int64(date.timeIntervalSince1970 * 1000)
        return String(epochMillis)
    }
}

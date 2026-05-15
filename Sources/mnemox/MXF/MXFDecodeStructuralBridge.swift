import Foundation

internal enum MXFDecodeGraphSnapshots {
    static func fileOutline(_ model: FileDependency) -> MXFNode {
        let links = model.imports.map { shard in
            MXFRelationship(operation: .depends, target: shard.modulePath, cardinality: .zeroOrOne)
        }

        return MXFNode(type: .file, identifier: model.path, attributes: ["framework": model.framework ?? ""], children: [], relationships: links)
    }

    static func componentOutline(_ face: ComponentInterface) -> MXFNode {
        let links = face.relationalTargets.map { shard in
            MXFRelationship(operation: .depends, target: shard, cardinality: .zeroOrOne)
        }

        return MXFNode(type: .props, identifier: face.path, attributes: ["propCount": "\(face.props.count)"], children: [], relationships: links)
    }

    static func conventionOutline(_ profile: ConventionProfile) -> MXFNode {
        MXFNode(
            type: .convention,
            identifier: profile.frameworkTags.joined(separator: " "),
            attributes: ["ruleCount": "\(profile.ruleLines.count)"],
            children: [],
            relationships: []
        )
    }

    static func planOutline(_ plan: ExecutionPlan) -> MXFNode {
        let kids = plan.steps.map { step in
            MXFNode(type: .symbol, identifier: "\(step.number):\(step.agentCode)", attributes: ["directive": step.directive], children: [], relationships: [])
        }

        return MXFNode(type: .plan, identifier: "\(plan.action)/\(plan.target)", attributes: [:], children: kids, relationships: [])
    }

    static func impactOutline(_ document: String) throws -> MXFNode {
        let rows = OutlineRows.compacted(document)
        guard let head = rows.first else { throw MXFDecodeError.emptyDocument }
        guard head.text.hasPrefix("IMPACT:") else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        let narrative = head.text.dropFirst("IMPACT:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = narrative.split(separator: " ", maxSplits: 1).map(String.init)
        guard let symbol = pieces.first else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        let change = pieces.count > 1 ? pieces[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        guard change.isEmpty == false else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        var children: [MXFNode] = []

        try rows.dropFirst().forEach { slice in
            let body = IndentScribe.relax(slice.text)
            let impact = try ImpactRowScribe.parse(body, line: slice.line)
            children.append(
                MXFNode(
                    type: .symbol,
                    identifier: impact.path,
                    attributes: [
                        "reason": impact.reason,
                        "updateType": impact.updateType,
                        "requiresModelIntervention": impact.requiresModelIntervention ? "true" : "false",
                    ],
                    children: [],
                    relationships: []
                )
            )
        }

        return MXFNode(type: .impact, identifier: symbol, attributes: ["change": change], children: children, relationships: [])
    }

    static func messageOutline(_ envelope: AgentMessage) -> MXFNode {
        var attributes: [String: String] = [
            "from": envelope.from,
            "to": envelope.to,
            "kind": envelope.kind.rawValue,
        ]

        if let corr = envelope.correlationID {
            attributes["corr"] = corr.uuidString.lowercased()
        }

        attributes["payloadBytes"] = "\(envelope.payload.utf8.count)"

        return MXFNode(type: .message, identifier: envelope.id.uuidString.lowercased(), attributes: attributes, children: [], relationships: [])
    }
}

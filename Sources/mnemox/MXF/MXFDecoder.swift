import Foundation

/// Rich failures emitted while hydrating Mnemox models from deterministic wire payloads.
public enum MXFDecodeError: Error, Equatable, Sendable {
    case emptyDocument
    case unexpectedLine(Int, String)
    case malformedBracketList(Int)
    case malformedPropFragment(Int)
    case malformedUUID(field: String, rawValue: String, line: Int)
    case malformedTimestamp(rawValue: String, line: Int)
    case missingPayloadSeparator(Int)
    case invalidMessageRoutingLine(Int, String)
    case invalidImpactRow(Int, String)
    case invalidRootHeader(String)
}

/// Mirrors MXFEncoder by parsing deterministic documents without admitting partially formed structs.
public enum MXFDecoder {
    public static func decode(_ document: String) throws -> MXFNode {
        guard let sentinel = OutlineRows.firstMeaning(document) else {
            throw MXFDecodeError.emptyDocument
        }

        if sentinel.hasPrefix("PLAN:") {
            return MXFDecodeGraphSnapshots.planOutline(try decodeExecutionPlan(document))
        }

        if sentinel.hasPrefix("MSG ") {
            return MXFDecodeGraphSnapshots.messageOutline(try decodeAgentMessage(document))
        }

        if sentinel.hasPrefix("IMPACT:") {
            return try MXFDecodeGraphSnapshots.impactOutline(document)
        }

        guard sentinel.hasPrefix("#") else {
            if sentinel.split(whereSeparator: { $0.isWhitespace }).contains(where: { token in token.starts(with: "@") }) {
                return MXFDecodeGraphSnapshots.conventionOutline(try decodeConventionProfile(document))
            }
            throw MXFDecodeError.invalidRootHeader(String(sentinel.prefix(120)))
        }

        let componentLike = document.contains("props[")
        if componentLike {
            return MXFDecodeGraphSnapshots.componentOutline(try decodeComponentInterface(document))
        }

        return MXFDecodeGraphSnapshots.fileOutline(try decodeFileDependency(document))
    }

    public static func decodeFileDependency(_ mxf: String) throws -> FileDependency {
        let rows = OutlineRows.compacted(mxf)
        guard let head = rows.first else { throw MXFDecodeError.emptyDocument }
        guard head.text.hasPrefix("#") else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        let peeled = HeadingScribe.fileHeading(String(head.text.dropFirst()))
        guard peeled.path.isEmpty == false else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        var imports: [FileDependency.ImportRef] = []
        var autos: [String] = []
        var tmpl: [String] = []

        try rows.dropFirst().forEach { slice in
            let body = IndentScribe.relax(slice.text)
            if body.hasPrefix("<-") {
                imports.append(try ImportScribe.ingest(body, line: slice.line))
                return
            }
            if body.hasPrefix("auto[") {
                autos.append(contentsOf: try BracketScribe.ingest(body, opener: "auto[", line: slice.line))
                return
            }
            if body.hasPrefix("tmpl[") {
                tmpl.append(contentsOf: try BracketScribe.ingest(body, opener: "tmpl[", line: slice.line))
                return
            }
            throw MXFDecodeError.unexpectedLine(slice.line, slice.text)
        }

        return FileDependency(path: peeled.path, framework: peeled.framework, imports: imports, autoSymbols: autos, templateComponents: tmpl)
    }

    public static func decodeComponentInterface(_ mxf: String) throws -> ComponentInterface {
        let rows = OutlineRows.compacted(mxf)
        guard let head = rows.first else { throw MXFDecodeError.emptyDocument }
        guard head.text.hasPrefix("#") else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        let peeled = HeadingScribe.fileHeading(String(head.text.dropFirst()))
        guard peeled.path.isEmpty == false else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        var props: [ComponentInterface.Prop] = []
        var relations: [String] = []

        try rows.dropFirst().forEach { slice in
            let body = IndentScribe.relax(slice.text)

            if body.hasPrefix("props[") {
                props.append(contentsOf: try PropScribe.ingest(body, line: slice.line))
                return
            }

            if body.hasPrefix("<-") {
                let target = body.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
                guard target.isEmpty == false else { throw MXFDecodeError.unexpectedLine(slice.line, slice.text) }
                relations.append(String(target))
                return
            }

            throw MXFDecodeError.unexpectedLine(slice.line, slice.text)
        }

        return ComponentInterface(path: peeled.path, framework: peeled.framework, props: props, relationalTargets: relations)
    }

    public static func decodeConventionProfile(_ mxf: String) throws -> ConventionProfile {
        let rows = OutlineRows.compacted(mxf)
        guard let head = rows.first else { throw MXFDecodeError.emptyDocument }

        let tokens = head.text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.contains(where: { token in token.starts(with: "@") }) else {
            throw MXFDecodeError.unexpectedLine(head.line, head.text)
        }

        let descriptors = tokens.map { token in token.starts(with: "@") ? token : "@\(token)" }.filter { $0.isEmpty == false }
        guard descriptors.isEmpty == false else {
            throw MXFDecodeError.unexpectedLine(head.line, head.text)
        }

        let tail = rows.dropFirst().filter { OutlineRows.nonBlank($0.text) }.map(\.text)

        return ConventionProfile(frameworkTags: descriptors, ruleLines: tail)
    }

    public static func decodeExecutionPlan(_ mxf: String) throws -> ExecutionPlan {
        let rows = OutlineRows.compacted(mxf)
        guard let head = rows.first else { throw MXFDecodeError.emptyDocument }
        guard head.text.hasPrefix("PLAN:") else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        let gist = head.text.dropFirst("PLAN:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        let chips = gist.split(separator: "/", maxSplits: 1).map(String.init)
        guard chips.count == 2 else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }
        let action = chips[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let target = chips[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard action.isEmpty == false, target.isEmpty == false else { throw MXFDecodeError.unexpectedLine(head.line, head.text) }

        let steps = try rows.dropFirst().map { slice in
            try PlanScribe.ingest(IndentScribe.relax(slice.text), line: slice.line)
        }

        return ExecutionPlan(action: action, target: target, steps: steps)
    }

    public static func decodeAgentMessage(_ mxf: String) throws -> AgentMessage {
        let rows = OutlineRows.all(mxf)

        guard let head = rows.first else { throw MXFDecodeError.emptyDocument }
        guard head.text.hasPrefix("MSG ") else { throw MXFDecodeError.invalidMessageRoutingLine(head.line, head.text) }

        guard let pivot = rows.firstIndex(where: { $0.text == MXFTransmissionMarkers.payloadSeparatorLine }) else {
            throw MXFDecodeError.missingPayloadSeparator(rows.last?.line ?? 1)
        }

        let router = head.text.dropFirst("MSG ".count).trimmingCharacters(in: .whitespacesAndNewlines)
        let halves = router.split(separator: "->", maxSplits: 1).map(String.init)
        guard halves.count == 2 else {
            throw MXFDecodeError.invalidMessageRoutingLine(head.line, head.text)
        }

        let source = halves[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let right = halves[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let words = right.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard source.isEmpty == false, words.count >= 2 else {
            throw MXFDecodeError.invalidMessageRoutingLine(head.line, head.text)
        }

        let destination = words[0]
        let kindToken = words.dropFirst().joined(separator: " ")
        guard let kind = MessageType(rawValue: kindToken) else {
            throw MXFDecodeError.invalidMessageRoutingLine(head.line, head.text)
        }

        var identifier: UUID?
        var dispatched: Date?
        var corr: UUID?

        if pivot > rows.index(after: rows.startIndex) {
            let band = rows[rows.index(after: rows.startIndex)..<pivot]
            try band.forEach { slice in
                let trimmed = slice.text.trimmingCharacters(in: .whitespacesAndNewlines)

                if let remnant = HeadingScribe.scalar("id:", trimmed) {
                    identifier = try HeadingScribe.uuidValue(remnant, label: "id", line: slice.line)
                    return
                }
                if let remnant = HeadingScribe.scalar("ts:", trimmed) {
                    dispatched = try HeadingScribe.instant(remnant, line: slice.line)
                    return
                }
                if let remnant = HeadingScribe.scalar("corr:", trimmed) {
                    corr = try HeadingScribe.uuidValue(remnant, label: "corr", line: slice.line)
                    return
                }

                guard trimmed.isEmpty else {
                    throw MXFDecodeError.unexpectedLine(slice.line, slice.text)
                }
            }
        }

        guard let resolvedID = identifier, let clock = dispatched else {
            throw MXFDecodeError.missingPayloadSeparator(head.line)
        }

        let trailing = rows[rows.index(after: pivot)...]
        let synthesized = OutlineRows.squeeze(trailing)

        return AgentMessage(
            id: resolvedID,
            from: source,
            to: destination,
            kind: kind,
            payload: synthesized,
            timestamp: clock,
            correlationID: corr
        )
    }
}

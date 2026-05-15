import Foundation

internal enum ImportScribe {
    static func ingest(_ body: String, line: Int) throws -> FileDependency.ImportRef {
        guard body.starts(with: "<-"),
              let left = body.firstIndex(of: "["),
              let right = body.lastIndex(of: "]"),
              left < right else { throw MXFDecodeError.unexpectedLine(line, body) }

        let module = body[body.index(body.startIndex, offsetBy: 2)..<left].trimmingCharacters(in: .whitespacesAndNewlines)
        guard module.isEmpty == false else { throw MXFDecodeError.unexpectedLine(line, body) }

        let inner = body[body.index(after: left)..<right]
        guard OutlineRows.nonBlank(String(inner)) else {
            return FileDependency.ImportRef(modulePath: String(module), symbols: [])
        }

        let shards = inner.split(separator: ",").map { token in token.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
        guard shards.isEmpty == false else {
            throw MXFDecodeError.malformedBracketList(line)
        }

        let strings = shards.map { fragment in String(fragment) }
        return FileDependency.ImportRef(modulePath: String(module), symbols: strings)
    }
}

internal enum BracketScribe {
    static func ingest(_ row: String, opener: String, line: Int) throws -> [String] {
        guard row.hasPrefix(opener), row.last == "]" else {
            throw MXFDecodeError.malformedBracketList(line)
        }
        let guts = row.dropFirst(opener.count).dropLast()
        guard OutlineRows.nonBlank(String(guts)) else {
            return []
        }
        let pieces = guts.split(separator: ",").map { token in token.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }

        let strings = pieces.map { fragment in String(fragment) }

        return strings
    }
}

internal enum PropScribe {
    static func ingest(_ row: String, line: Int) throws -> [ComponentInterface.Prop] {
        guard row.hasPrefix("props["), row.last == "]" else {
            throw MXFDecodeError.malformedPropFragment(line)
        }

        let core = row.dropFirst("props[".count).dropLast()
        guard OutlineRows.nonBlank(String(core)) else {
            throw MXFDecodeError.malformedPropFragment(line)
        }

        let glyphs = core.split(separator: ",").map { token in token.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }

        return try glyphs.map { token in try PropScribe.atom(String(token), line: line) }
    }

    private static func atom(_ token: String, line: Int) throws -> ComponentInterface.Prop {
        guard let splitter = token.firstIndex(of: ":"),
              let flagIndex = token[..<splitter].firstIndex(where: { $0 == "?" || $0 == "!" }),
              token.index(after: flagIndex) == splitter else {
            throw MXFDecodeError.malformedPropFragment(line)
        }

        let name = token[..<flagIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let qualifier = token[flagIndex]
        let tail = token[token.index(after: splitter)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false, tail.isEmpty == false else {
            throw MXFDecodeError.malformedPropFragment(line)
        }

        if let envelope = tail.range(of: "default=") {
            let abbreviatedType = tail[..<envelope.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let defaultTail = tail[envelope.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)

            guard abbreviatedType.isEmpty == false, defaultTail.isEmpty == false else {
                throw MXFDecodeError.malformedPropFragment(line)
            }

            let marker: ComponentInterface.OptionalityMarker = qualifier == "!" ? .required : .optional
            return ComponentInterface.Prop(name: name, abbreviatedType: abbreviatedType, optionality: marker, defaultValue: String(defaultTail))
        }

        let marker: ComponentInterface.OptionalityMarker = qualifier == "!" ? .required : .optional
        return ComponentInterface.Prop(name: name, abbreviatedType: tail, optionality: marker, defaultValue: nil)
    }
}

internal enum PlanScribe {
    static func ingest(_ row: String, line: Int) throws -> ExecutionPlan.Step {
        guard let colon = row.firstIndex(of: ":") else {
            throw MXFDecodeError.unexpectedLine(line, row)
        }

        let sequence = row[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        let remainder = row[row.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)

        guard let ordinal = Int(sequence), remainder.isEmpty == false else {
            throw MXFDecodeError.unexpectedLine(line, row)
        }

        guard let gap = remainder.firstIndex(where: { $0.isWhitespace }),
              remainder.index(after: gap) < remainder.endIndex else {
            throw MXFDecodeError.unexpectedLine(line, row)
        }

        let agent = remainder[..<gap].trimmingCharacters(in: .whitespacesAndNewlines)
        let command = remainder[remainder.index(after: gap)...].trimmingCharacters(in: .whitespacesAndNewlines)

        guard agent.isEmpty == false, command.isEmpty == false else {
            throw MXFDecodeError.unexpectedLine(line, row)
        }

        return ExecutionPlan.Step(number: ordinal, agentCode: String(agent), directive: String(command))
    }
}

internal enum ImpactRowScribe {
    static func parse(_ row: String, line: Int) throws -> (
        path: String,
        reason: String,
        updateType: String,
        requiresModelIntervention: Bool,
    ) {
        if row.range(of: "] update:", options: .backwards) != nil {
            return try parseModern(row, line: line)
        }
        return try parseLegacy(row, line: line)
    }

    private static func parseModern(_ row: String, line: Int) throws -> (
        path: String,
        reason: String,
        updateType: String,
        requiresModelIntervention: Bool,
    ) {
        guard let marker = row.range(of: "] update:", options: .backwards) else {
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        let prefix = row[..<marker.lowerBound]
        guard let openBracket = prefix.firstIndex(of: "[") else {
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        let path = prefix[..<openBracket].trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.isEmpty == false else {
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        let reason = prefix[prefix.index(after: openBracket)...].trimmingCharacters(in: .whitespacesAndNewlines)

        let tail = row[marker.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let modelMarker = tail.range(of: " model:") else {
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        let updateType = tail[..<modelMarker.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        guard updateType.isEmpty == false else {
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        let modelFlag = tail[modelMarker.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let requiresModel: Bool
        switch modelFlag {
        case "true":
            requiresModel = true
        case "false":
            requiresModel = false
        default:
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        return (path, String(reason), updateType, requiresModel)
    }

    private static func parseLegacy(_ row: String, line: Int) throws -> (
        path: String,
        reason: String,
        updateType: String,
        requiresModelIntervention: Bool,
    ) {
        guard let marker = row.range(of: "] requiresUpdate:", options: .backwards) else {
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        let prefix = row[..<marker.lowerBound]
        guard let openBracket = prefix.firstIndex(of: "[") else {
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        let path = prefix[..<openBracket].trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.isEmpty == false else {
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        let reason = prefix[prefix.index(after: openBracket)...].trimmingCharacters(in: .whitespacesAndNewlines)

        let flag = row[marker.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let requiresModel: Bool
        switch flag {
        case "true":
            requiresModel = true
        case "false":
            requiresModel = false
        default:
            throw MXFDecodeError.invalidImpactRow(line, row)
        }

        return (path, String(reason), "legacy-requires-update", requiresModel)
    }
}

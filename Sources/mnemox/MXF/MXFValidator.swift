import Foundation

/// Structural gatekeeper rejecting malformed Mnemox Format payloads before orchestration dispatches models.
public enum MXFValidator {
    /// Performs a deep structural pass over generic MXF text using deterministic parser failures as diagnostics.
    public static func validate(_ mxf: String) -> ValidationResult {
        guard OutlineRows.nonBlank(mxf) else {
            return .invalid([
                MXFValidationIssue(line: 1, column: 1, message: "MXF payload is empty or whitespace-only"),
            ])
        }

        let trimmedEnvelope = MXFNormalizer.dropOuterBlankLines(in: mxf)

        guard trimmedEnvelope.canonical.isEmpty == false else {
            return .invalid([
                MXFValidationIssue(line: 1, column: 1, message: "MXF payload collapses after trimming boundary blanks"),
            ])
        }

        do {
            _ = try MXFDecoder.decode(trimmedEnvelope.canonical)
            return .valid
        } catch let failure as MXFDecodeError {
            return .invalid([MXFNormalizer.digest(failure)])
        } catch {
            return .invalid([
                MXFValidationIssue(line: 1, column: 1, message: "Unexpected MXF parser failure \(error.localizedDescription)"),
            ])
        }
    }

    /// Re-serializes a message envelope and validates the resulting MXF for MessageBus egress.
    public static func validateMessage(_ message: AgentMessage) -> ValidationResult {
        validate(MXFEncoder.encode(message))
    }
}

private enum MXFNormalizer {
    struct TrimEnvelope {
        let canonical: String
    }

    static func digest(_ fault: MXFDecodeError) -> MXFValidationIssue {
        switch fault {
        case .emptyDocument:
            return MXFValidationIssue(line: 1, column: 1, message: "Decoded MXF text was unexpectedly empty.")
        case .unexpectedLine(let line, let excerpt):
            return MXFValidationIssue(line: line, column: 1, message: "Unexpected MXF row: \(excerpt.prefix(240))")
        case .malformedBracketList(let line):
            return MXFValidationIssue(line: line, column: 1, message: "Bracket list malformed or duplicated delimiters.")
        case .malformedPropFragment(let line):
            return MXFValidationIssue(line: line, column: 7, message: "`props[...]` block contains invalid fragments.")
        case let .malformedUUID(field, rawValue, line):
            return MXFValidationIssue(line: line, column: 5, message: "UUID field \(field) token \(rawValue) is invalid.")
        case let .malformedTimestamp(rawValue, line):
            return MXFValidationIssue(line: line, column: 5, message: "`ts:` value \(rawValue) failed ISO-8601 or epoch millis parsing.")
        case let .missingPayloadSeparator(line):
            return MXFValidationIssue(line: line, column: 1, message: "Envelope missing <<<PAYLOAD>>> sentinel or metadata malformed.")
        case let .invalidMessageRoutingLine(line, excerpt):
            return MXFValidationIssue(line: line, column: 1, message: "Malformed MSG routing line \(excerpt.prefix(240))")
        case let .invalidImpactRow(line, excerpt):
            return MXFValidationIssue(line: line, column: 3, message: "IMPACT detail row malformed: \(excerpt.prefix(240))")
        case .invalidRootHeader(let preview):
            return MXFValidationIssue(line: 1, column: 1, message: "Unrecognized Mnemox root signature `\(preview)`")
        }
    }

    static func dropOuterBlankLines(in manuscript: String) -> TrimEnvelope {
        let shards = manuscript.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard let head = shards.firstIndex(where: { OutlineRows.nonBlank($0) }),
              let tail = shards.lastIndex(where: { OutlineRows.nonBlank($0) }) else {
            return TrimEnvelope(canonical: "")
        }

        let clamped = Array(shards[head...tail])
        return TrimEnvelope(canonical: clamped.joined(separator: "\n"))
    }
}

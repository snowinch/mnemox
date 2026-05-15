import Foundation

internal struct MXFDecodedRow {
    let line: Int
    let text: String
}

internal enum OutlineRows {
    static func firstMeaning(_ document: String) -> String? {
        document.split(separator: "\n").map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { $0.isEmpty == false })
    }

    static func nonBlank(_ row: String) -> Bool {
        row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    static func all(_ document: String) -> [MXFDecodedRow] {
        enumerated(document.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
    }

    static func compacted(_ document: String) -> [MXFDecodedRow] {
        let rows = all(document)

        guard let head = rows.firstIndex(where: { nonBlank($0.text) }), let tail = rows.lastIndex(where: { nonBlank($0.text) }) else {
            return []
        }

        return Array(rows[head...tail])
    }

    private static func enumerated(_ rows: [String]) -> [MXFDecodedRow] {
        rows.enumerated().map { offset, fragment in MXFDecodedRow(line: offset + 1, text: fragment) }
    }

    static func squeeze(_ window: ArraySlice<MXFDecodedRow>) -> String {
        guard window.isEmpty == false else { return "" }

        var lead = window[window.startIndex...]
        while lead.isEmpty == false, nonBlank(lead.first?.text ?? "") == false {
            lead = lead.dropFirst()
        }

        guard lead.isEmpty == false else { return "" }

        var trailer = lead
        while trailer.isEmpty == false, nonBlank(trailer.last?.text ?? "") == false {
            trailer = trailer.dropLast()
        }

        guard trailer.isEmpty == false else { return "" }

        return trailer.map(\.text).joined(separator: "\n")
    }
}

internal enum IndentScribe {
    static func relax(_ row: String) -> String {
        if row.hasPrefix("  ") {
            return String(row.dropFirst(2))
        }
        return row.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

internal enum HeadingScribe {
    static func fileHeading(_ raw: String) -> (path: String, framework: String?) {
        let chips = raw.split(separator: "@", maxSplits: 1).map(String.init)

        guard let lead = chips.first else { return ("", nil) }

        let path = lead.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chips.count > 1 else { return (path, nil) }
        let secondary = chips[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard secondary.isEmpty == false else { return (path, nil) }
        return (path, secondary)
    }

    static func scalar(_ prefix: String, _ row: String) -> String? {
        guard row.hasPrefix(prefix) else { return nil }
        let condensed = row.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard condensed.isEmpty == false else { return nil }
        return String(condensed)
    }

    static func uuidValue(_ token: String, label: String, line: Int) throws -> UUID {
        guard let value = UUID(uuidString: token) else {
            throw MXFDecodeError.malformedUUID(field: label, rawValue: token, line: line)
        }
        return value
    }

    static func instant(_ token: String, line: Int) throws -> Date {
        let precise = HeadingScribe.fractionalClock
        let coarse = HeadingScribe.plainClock

        if let date = precise.date(from: token) {
            return date
        }

        if let coarseDate = coarse.date(from: token) {
            return coarseDate
        }

        if let millis = Int64(token) {
            return Date(timeIntervalSince1970: TimeInterval(Double(millis) / 1_000))
        }

        throw MXFDecodeError.malformedTimestamp(rawValue: token, line: line)
    }

    private static let fractionalClock: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainClock: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

import Foundation

/// JSX/TS tooling coverage via regex-backed Phase 1 extractors (Phase 1 Parsers).
public enum TypeScriptParser {
    public static func extractImports(from source: String) -> [FileDependency.ImportRef] {
        var bucket: [String: Set<String>] = [:]

        for match in source.matches(of: #/import\s*(?:type\s*)?\{([^}]*)\}\s*from\s*["']([^"']+)["']/#) {
            let module = String(match.2)
            let symbolsPart = String(match.1)
            accumulateSymbols(&bucket, module: module, symbolsPart: symbolsPart)
        }

        for match in source.matches(of: #/import\s+\*\s+as\s+\w+\s+from\s*["']([^"']+)["']/#) {
            let module = String(match.1)
            bucket[module, default: []].insert("*")
        }

        for match in source.matches(of: #/import\s+\w+\s*,\s*\{([^}]*)\}\s*from\s*["']([^"']+)["']/#) {
            let symbolsPart = String(match.1)
            let module = String(match.2)
            accumulateSymbols(&bucket, module: module, symbolsPart: symbolsPart)
        }

        for match in source.matches(of: #/import\s+(?!type\b)(\w+)\s*,\s*(\w+)\s+from\s*["']([^"']+)["']/#) {
            let module = String(match.3)
            bucket[module, default: []].insert(String(match.1))
            bucket[module, default: []].insert(String(match.2))
        }

        for match in source.matches(of: #/import\s+(?!type\b)(\w+)\s+from\s*["']([^"']+)["']/#) {
            let module = String(match.2)
            bucket[module, default: []].insert(String(match.1))
        }

        for match in source.matches(of: #/import\s*["']([^"']+)["']/#) {
            bucket[String(match.1), default: []].insert("*")
        }

        for match in source.matches(of: #/require\(\s*["']([^"']+)["']\s*\)/#) {
            bucket[String(match.1), default: []].insert("*")
        }

        for match in source.matches(of: #/import\(\s*["']([^"']+)["']\s*\)/#) {
            bucket[String(match.1), default: []].insert("*")
        }

        return bucket.keys.sorted().map { key in
            FileDependency.ImportRef(modulePath: key, symbols: Array(bucket[key] ?? []).sorted())
        }
    }

    public static func vueScriptBody(from source: String) -> String {
        guard let openRange = source.range(of: #"<script\b[^>]*>"#, options: .regularExpression) else {
            return ""
        }
        let afterOpen = source[openRange.upperBound...]
        guard let closeRange = afterOpen.range(of: #"</script>"#, options: .regularExpression) else {
            return String(afterOpen)
        }
        return String(afterOpen[..<closeRange.lowerBound])
    }

    private static func accumulateSymbols(
        _ bucket: inout [String: Set<String>],
        module: String,
        symbolsPart: String,
    ) {
        let segments = symbolsPart.split(separator: ",")
        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                continue
            }
            let head = trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? trimmed
            guard head.isEmpty == false else {
                continue
            }
            bucket[module, default: []].insert(head)
        }
    }
}

import Foundation

/// Regex-backed Python import extraction for FastAPI/Django trees (Phase 1).
public enum PythonParser {
    public static func extractImports(from source: String) -> [FileDependency.ImportRef] {
        var refs: [String: Set<String>] = [:]

        let fromLines = source.matches(of: #/(?m)^\s*from\s+([\w.]+)\s+import\s+([^#\n]+)/#)
        for match in fromLines {
            let module = String(match.1)
            let rhs = String(match.2)
            let symbols = rhs
                .replacingOccurrences(of: "(", with: " ")
                .replacingOccurrences(of: ")", with: " ")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.isEmpty == false && $0 != "*" }
            if symbols.isEmpty {
                refs[module, default: []].insert("*")
            } else {
                for symbol in symbols {
                    refs[module, default: []].insert(symbol)
                }
            }
        }

        let importLines = source.matches(of: #/(?m)^\s*import\s+([^#\n]+)/#)
        for match in importLines {
            let chunk = String(match.1)
            let segments = chunk.split(separator: ",")
            for segment in segments {
                let trimmed = segment.trimmingCharacters(in: .whitespaces)
                guard trimmed.isEmpty == false else {
                    continue
                }
                let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
                guard let first = parts.first else {
                    continue
                }
                let module = first.split(separator: ".").first.map(String.init) ?? first
                refs[module, default: []].insert("*")
            }
        }

        return refs.keys.sorted().map { key in
            FileDependency.ImportRef(modulePath: key, symbols: Array(refs[key] ?? []).sorted())
        }
    }

    public static func mentionsFastAPI(source: String) -> Bool {
        source.range(of: #"\b(import\s+fastapi|from\s+fastapi\b)"#, options: .regularExpression) != nil
    }
}

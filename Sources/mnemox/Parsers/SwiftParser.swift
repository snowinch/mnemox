import Foundation

/// Regex-backed Swift import extraction for SPM / SwiftUI repositories (Phase 1).
public enum SwiftParser {
    public static func extractImports(from source: String) -> [FileDependency.ImportRef] {
        var refs: [String: Set<String>] = [:]
        for line in source.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("import ") else {
                continue
            }
            let rest = trimmed.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
            guard rest.isEmpty == false else {
                continue
            }
            let module = rest.split(whereSeparator: { $0 == "." }).first.map(String.init) ?? String(rest)
            let cleaned = module.trimmingCharacters(in: .whitespaces)
            guard cleaned.isEmpty == false else {
                continue
            }
            refs[cleaned, default: []].insert("*")
        }

        return refs.keys.sorted().map { key in
            FileDependency.ImportRef(modulePath: key, symbols: Array(refs[key] ?? []).sorted())
        }
    }

    public static func mentionsSwiftUI(source: String) -> Bool {
        source.range(of: #"\bimport\s+SwiftUI\b"#, options: .regularExpression) != nil
    }
}

import Foundation

/// Language dispatcher routing repository files to Phase 1 extractors.
public enum UniversalParser {
    /// Parses import metadata for a single repository file relative to `projectRoot`.
    public static func dependency(for fileURL: URL, projectRoot: URL) async throws -> FileDependency {
        let data = try await Self.loadFileData(from: fileURL)
        let source = String(decoding: data, as: UTF8.self)
        let relativePath = fileURL.pathRelative(to: projectRoot)
        let imports = extractImports(source: source, pathExtension: fileURL.pathExtension.lowercased())
        let framework = inferFrameworkTag(extension: fileURL.pathExtension.lowercased())
        return FileDependency(
            path: relativePath,
            framework: framework,
            imports: imports,
            autoSymbols: [],
            templateComponents: [],
        )
    }

    /// Imports-only extraction exposed for deterministic scanners that already loaded sources.
    public static func extractImports(source: String, pathExtension: String) -> [FileDependency.ImportRef] {
        let normalized = pathExtension.lowercased()
        switch normalized {
        case "swift":
            return SwiftParser.extractImports(from: source)
        case "py":
            return PythonParser.extractImports(from: source)
        case "vue":
            return TypeScriptParser.extractImports(from: TypeScriptParser.vueScriptBody(from: source))
        case "ts", "tsx", "js", "jsx", "mjs", "cjs":
            return TypeScriptParser.extractImports(from: source)
        default:
            return GenericParser.extractImports(from: source)
        }
    }

    private static func inferFrameworkTag(extension ext: String) -> String? {
        switch ext.lowercased() {
        case "swift":
            return "swift"
        case "vue":
            return "vue"
        case "tsx", "jsx":
            return "react"
        default:
            return nil
        }
    }

    nonisolated private static func loadFileData(from url: URL) async throws -> Data {
        try await Task.detached(priority: .utility) {
            try Data(contentsOf: url)
        }.value
    }
}

extension URL {
    func pathRelative(to root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = standardizedFileURL.path
        guard filePath.count >= rootPath.count, filePath.hasPrefix(rootPath) else {
            return standardizedFileURL.lastPathComponent
        }
        let start = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        var suffix = String(filePath[start...])
        if suffix.hasPrefix("/") {
            suffix.removeFirst()
        }
        return suffix
    }
}

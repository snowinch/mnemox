import Foundation

/// Fallback extractor when no specialist parser applies (Phase 1).
public enum GenericParser {
    public static func extractImports(from source: String) -> [FileDependency.ImportRef] {
        TypeScriptParser.extractImports(from: source)
    }
}

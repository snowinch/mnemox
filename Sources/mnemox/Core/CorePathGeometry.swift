import Foundation

enum CorePathGeometry {
    static func resolveImport(
        specifier: String,
        importerRelative: String,
        rootURL: URL,
        aliases: [String: String],
    ) -> String? {
        var spec = specifier
        let sortedAliases = aliases.keys.sorted { $0.count > $1.count }
        for alias in sortedAliases {
            guard let replacement = aliases[alias], spec.hasPrefix(alias) else {
                continue
            }
            spec = replacement + String(spec.dropFirst(alias.count))
            break
        }

        guard spec.hasPrefix(".") else {
            return nil
        }

        let root = rootURL.standardizedFileURL
        let importerURL = root.appendingPathComponent(importerRelative).standardizedFileURL
        let directoryURL = importerURL.deletingLastPathComponent()
        let resolvedURL = directoryURL.appendingPathComponent(spec).standardizedFileURL
        let rootPath = root.path
        let resolvedPath = resolvedURL.path
        guard resolvedPath.count >= rootPath.count, resolvedPath.hasPrefix(rootPath) else {
            return nil
        }

        let relative = resolvedURL.pathRelative(to: root)
        let normalized = normalizePOSIX(relative)
        guard normalized.isEmpty == false else {
            return nil
        }

        let candidateURL = root.appendingPathComponent(normalized)
        if FileManager.default.fileExists(atPath: candidateURL.path) {
            return normalized
        }

        let candidateSwift = normalized + ".swift"
        if FileManager.default.fileExists(atPath: root.appendingPathComponent(candidateSwift).path) {
            return candidateSwift
        }

        for ext in ["ts", "tsx", "js", "jsx", "vue", "py"] {
            let candidate = "\(normalized).\(ext)"
            if FileManager.default.fileExists(atPath: root.appendingPathComponent(candidate).path) {
                return candidate
            }
        }

        return normalized
    }

    private static func normalizePOSIX(_ relative: String) -> String {
        let trimmed = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmed.isEmpty == false else {
            return ""
        }
        var stack: [String] = []
        for part in trimmed.split(separator: "/") {
            if part == "." || part.isEmpty {
                continue
            }
            if part == ".." {
                _ = stack.popLast()
            } else {
                stack.append(String(part))
            }
        }
        return stack.joined(separator: "/")
    }
}

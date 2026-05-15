import Foundation

/// Derives writer-facing convention payloads capped for MXF budgets.
public struct ConventionProfiler: Sendable {
    public init() {}

    public func profile(root: URL, snapshot: ProjectSnapshot) async throws -> ConventionProfile {
        let rootURL = root.standardizedFileURL
        let frameworks = ProjectScanner.detectFrameworks(root: rootURL)
        let languages = Self.languageFingerprint(snapshot.files.map(\.relativePath))
        let deps = ConventionArtifacts.packageDependencyKeys(root: rootURL)
        let testing = ConventionArtifacts.detectTesting(root: rootURL, deps: deps)
        let detailed = ConventionArtifacts.detailedProfile(
            root: rootURL,
            frameworks: frameworks,
            dominantLanguages: languages,
            testingSignals: testing,
        )
        return ConventionArtifacts.cappedMXFProfile(detailed, maxTokens: 25)
    }

    private static func languageFingerprint(_ relatives: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for relative in relatives {
            let ext = (relative as NSString).pathExtension.lowercased()
            let language = Self.languageLabel(for: ext)
            counts[language, default: 0] += 1
        }
        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }.map(\.key)
    }

    private static func languageLabel(for ext: String) -> String {
        switch ext {
        case "ts", "tsx":
            return "ts"
        case "js", "jsx":
            return "js"
        case "vue":
            return "vue"
        case "swift":
            return "swift"
        case "py":
            return "py"
        default:
            return ext
        }
    }
}

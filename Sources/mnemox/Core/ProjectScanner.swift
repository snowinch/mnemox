import Foundation

/// Walks repositories detecting language fingerprints, frameworks, and baseline conventions.
public struct ProjectScanner: Sendable {
    private static let skippedDirectories: Set<String> = ["node_modules", ".next", "dist", ".build", "__pycache__", ".git"]
    private static let sourceExtensions: Set<String> = ["ts", "tsx", "vue", "py", "swift", "js", "jsx"]

    public init() {}

    /// Lists tracked extensions while honoring intelligence-layer skip rules.
    public static func trackedSourceFiles(root: URL) throws -> [String] {
        try collectSourceFiles(rootURL: root.standardizedFileURL)
    }

    public func scan(root: URL) async throws -> ProjectSnapshot {
        let rootURL = root.standardizedFileURL
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            throw CoreIntelligenceError.missingRoot(rootURL)
        }

        let relatives = try Self.collectSourceFiles(rootURL: rootURL)
        let languageSignature = Self.languageHistogram(from: relatives)
        var frameworks = Self.detectFrameworks(root: rootURL)

        if Self.projectImportsSwiftUI(rootURL: rootURL, swiftRelatives: relatives) {
            frameworks.insert("swiftui")
        }

        let fileSnapshots = try await Self.hashSources(rootURL: rootURL, relatives: relatives)
        let profile = ConventionArtifacts.scanProfile(
            root: rootURL,
            frameworks: frameworks,
            dominantLanguages: languageSignature,
        )

        let steps = frameworks.sorted().enumerated().map { index, tag in
            ExecutionPlan.Step(number: index + 1, agentCode: "SIG", directive: "framework:\(tag)")
        }

        let plan = ExecutionPlan(action: "scan", target: rootURL.path, steps: steps)
        let conventionWire = profile.encodeToMXF()

        return ProjectSnapshot(
            id: Self.makeSnapshotID(prefix: "scan"),
            timestamp: Date(),
            files: fileSnapshots,
            agentPlan: plan,
            mxfLog: conventionWire.isEmpty ? [] : [conventionWire],
        )
    }

    public static func detectFrameworks(root: URL) -> Set<String> {
        let rootURL = root.standardizedFileURL
        let fm = FileManager.default
        var tags = Set<String>()

        let nuxtNames = ["nuxt.config.ts", "nuxt.config.js", "nuxt.config.mjs"]
        let hasNuxt = nuxtNames.contains { fm.fileExists(atPath: rootURL.appendingPathComponent($0).path) }

        let nextNames = ["next.config.js", "next.config.ts", "next.config.mjs", "next.config.cjs"]
        let hasNext = nextNames.contains { fm.fileExists(atPath: rootURL.appendingPathComponent($0).path) }

        if hasNuxt {
            tags.insert("nuxt")
        }
        if hasNext {
            tags.insert("next")
        }

        let deps = ConventionArtifacts.packageDependencyKeys(root: rootURL)
        if hasNuxt == false, deps.contains("vue") {
            tags.insert("vue")
        }
        if hasNext == false, deps.contains("react") {
            tags.insert("react")
        }

        if ConventionArtifacts.requirementsContainsFastAPI(root: rootURL) || shallowFastAPIImport(root: rootURL) {
            tags.insert("fastapi")
        }

        if fm.fileExists(atPath: rootURL.appendingPathComponent("manage.py").path) {
            tags.insert("django")
        }

        if fm.fileExists(atPath: rootURL.appendingPathComponent("Package.swift").path) {
            tags.insert("spm")
        }

        return tags
    }

    private static func collectSourceFiles(rootURL: URL) throws -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
        ) else {
            throw CoreIntelligenceError.missingRoot(rootURL)
        }

        var relatives: [String] = []
        for case let itemURL as URL in enumerator {
            let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                let name = itemURL.lastPathComponent
                if skippedDirectories.contains(name) {
                    enumerator.skipDescendants()
                }
                continue
            }

            let ext = itemURL.pathExtension.lowercased()
            guard sourceExtensions.contains(ext) else {
                continue
            }
            relatives.append(itemURL.pathRelative(to: rootURL))
        }

        return relatives.sorted()
    }

    private static func hashSources(rootURL: URL, relatives: [String]) async throws -> [ProjectSnapshot.FileSnapshot] {
        try await withThrowingTaskGroup(of: ProjectSnapshot.FileSnapshot.self) { group in
            for relative in relatives {
                group.addTask {
                    let fileURL = rootURL.appendingPathComponent(relative)
                    let data = try Data(contentsOf: fileURL)
                    let digest = CoreDigest.sha256Hex(for: data)
                    return ProjectSnapshot.FileSnapshot(relativePath: relative, sha256: digest)
                }
            }

            var snapshots: [ProjectSnapshot.FileSnapshot] = []
            while let next = try await group.next() {
                snapshots.append(next)
            }
            return snapshots.sorted { $0.relativePath < $1.relativePath }
        }
    }

    private static func languageHistogram(from relatives: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for relative in relatives {
            let ext = (relative as NSString).pathExtension.lowercased()
            let language = languageLabel(for: ext)
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

    private static func projectImportsSwiftUI(rootURL: URL, swiftRelatives: [String]) -> Bool {
        let swiftPaths = swiftRelatives.filter { $0.hasSuffix(".swift") }
        for relative in swiftPaths.prefix(256) {
            let url = rootURL.appendingPathComponent(relative)
            guard let data = try? Data(contentsOf: url),
                  let source = String(data: data, encoding: .utf8) else {
                continue
            }
            if SwiftParser.mentionsSwiftUI(source: source) {
                return true
            }
        }
        return false
    }

    private static func shallowFastAPIImport(root: URL) -> Bool {
        let rootURL = root.standardizedFileURL
        let candidates = ["main.py", "app/main.py", "src/main.py", "api/main.py"]
        for relative in candidates {
            let url = rootURL.appendingPathComponent(relative)
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {
                continue
            }
            if PythonParser.mentionsFastAPI(source: text) {
                return true
            }
        }
        return false
    }

    private static func makeSnapshotID(prefix: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return "\(prefix)_\(stamp)"
    }
}

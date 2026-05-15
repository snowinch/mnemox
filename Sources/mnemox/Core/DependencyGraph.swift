import Foundation

/// Bidirectional import graph built from [`UniversalParser`] plus resolver hints.
public struct DependencyGraph: Codable, Equatable, Sendable {
    public let rootPath: String
    private let nodes: [String: FileDependency]
    private let outgoing: [String: [String]]
    private let incoming: [String: [String]]

    public init(rootPath: String, nodes: [String: FileDependency], outgoing: [String: Set<String>], incoming: [String: Set<String>]) {
        self.rootPath = rootPath
        self.nodes = nodes
        self.outgoing = outgoing.mapValues { $0.sorted() }
        self.incoming = incoming.mapValues { $0.sorted() }
    }

    public func encodeToMXF() -> String {
        nodes.keys.sorted().compactMap { nodes[$0] }.map { MXFEncoder.encode($0) }.joined(separator: "\n\n")
    }

    public static func build(from snapshot: ProjectSnapshot) async throws -> DependencyGraph {
        let rootURL = URL(fileURLWithPath: snapshot.agentPlan.target).standardizedFileURL
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            throw CoreIntelligenceError.missingRoot(rootURL)
        }

        let aliases = ConventionArtifacts.tsconfigAliases(root: rootURL)
        var nodes: [String: FileDependency] = [:]
        var outgoingSets: [String: Set<String>] = [:]
        var incomingSets: [String: Set<String>] = [:]

        for tracked in snapshot.files {
            let url = rootURL.appendingPathComponent(tracked.relativePath)
            let dependency = try await UniversalParser.dependency(for: url, projectRoot: rootURL)
            nodes[tracked.relativePath] = dependency

            var neighbors = Set<String>()
            for ref in dependency.imports {
                guard let resolved = CorePathGeometry.resolveImport(
                    specifier: ref.modulePath,
                    importerRelative: tracked.relativePath,
                    rootURL: rootURL,
                    aliases: aliases,
                ) else {
                    continue
                }
                neighbors.insert(resolved)
                incomingSets[resolved, default: []].insert(tracked.relativePath)
            }
            outgoingSets[tracked.relativePath] = neighbors
        }

        return DependencyGraph(
            rootPath: rootURL.path,
            nodes: nodes,
            outgoing: outgoingSets,
            incoming: incomingSets,
        )
    }

    public func dependencies(of file: URL) -> [FileDependency] {
        let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
        let relative = file.standardizedFileURL.pathRelative(to: rootURL)
        guard let targets = outgoing[relative] else {
            return []
        }
        return targets.compactMap { nodes[$0] }
    }

    public func dependents(of file: URL) -> [URL] {
        let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
        let relative = file.standardizedFileURL.pathRelative(to: rootURL)
        guard let parents = incoming[relative] else {
            return []
        }
        return parents.map { rootURL.appendingPathComponent($0).standardizedFileURL }
    }

    public func impactOf(changing file: URL) -> ImpactReport {
        let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
        let seed = file.standardizedFileURL.pathRelative(to: rootURL)
        var queue: [String] = incoming[seed] ?? []
        var visited = Set<String>()
        var ordered: [String] = []

        while queue.isEmpty == false {
            let node = queue.removeFirst()
            guard visited.contains(node) == false else {
                continue
            }
            visited.insert(node)
            ordered.append(node)
            for parent in incoming[node] ?? [] where visited.contains(parent) == false {
                queue.append(parent)
            }
        }

        let impacts = ordered.map { path -> ImpactReport.FileImpact in
            ImpactReport.FileImpact(
                path: path,
                reason: "Transitive importer of \(seed)",
                updateType: "stabilize-import",
                requiresModelIntervention: true,
            )
        }

        return ImpactReport(symbol: seed, changeType: "file-change", files: impacts)
    }

    func relativePath(for file: URL) -> String {
        let rootURL = URL(fileURLWithPath: rootPath).standardizedFileURL
        return file.standardizedFileURL.pathRelative(to: rootURL)
    }

    var trackedRelativePaths: [String] {
        nodes.keys.sorted()
    }

    func dependencyRecord(for relativePath: String) -> FileDependency? {
        nodes[relativePath]
    }

    func subgraphIncomingClosure(from seeds: [String]) -> [String] {
        var queue = seeds
        var visited = Set<String>()
        var ordered: [String] = []

        while queue.isEmpty == false {
            let node = queue.removeFirst()
            guard visited.contains(node) == false else {
                continue
            }
            visited.insert(node)
            ordered.append(node)
            for parent in incoming[node] ?? [] where visited.contains(parent) == false {
                queue.append(parent)
            }
        }
        return ordered
    }

    func topologicalOrdering(of files: [String]) -> [String] {
        let subset = Set(files)
        var indegree: [String: Int] = [:]
        for file in files {
            let deps = (outgoing[file] ?? []).filter { subset.contains($0) }
            indegree[file] = deps.count
        }

        var importedBy: [String: [String]] = [:]
        for file in files {
            for dependency in outgoing[file] ?? [] where subset.contains(dependency) {
                importedBy[dependency, default: []].append(file)
            }
        }

        var frontier = files.filter { indegree[$0] == 0 }.sorted()
        var ordered: [String] = []

        while frontier.isEmpty == false {
            let node = frontier.removeFirst()
            ordered.append(node)
            for dependent in importedBy[node] ?? [] {
                indegree[dependent, default: 1] -= 1
                if indegree[dependent] == 0 {
                    frontier.append(dependent)
                    frontier.sort()
                }
            }
        }

        if ordered.count != files.count {
            return files.sorted()
        }

        return ordered
    }
}

import Foundation

/// Projects downstream churn given structured edit intents.
public struct ImpactAnalyzer: Sendable {
    public init() {}

    public func analyze(change: ProposedChange, in graph: DependencyGraph) async throws -> ImpactReport {
        switch change {
        case let .fileMove(from, to):
            return analyzeFileMove(from: from, to: to, graph: graph)
        case let .symbolRename(name, place):
            return analyzeSymbolRename(name: name, file: place, graph: graph)
        case let .propsModified(component, place):
            return analyzeProps(component: component, file: place, graph: graph)
        case let .fileDelete(at):
            return analyzeDeletion(at: at, graph: graph)
        }
    }

    private func analyzeFileMove(from: URL, to: URL, graph: DependencyGraph) -> ImpactReport {
        let oldPath = graph.relativePath(for: from)
        let newPath = graph.relativePath(for: to)
        let dependents = graph.subgraphIncomingClosure(from: [oldPath]).filter { $0 != oldPath }

        let impacts = dependents.map { path -> ImpactReport.FileImpact in
            ImpactReport.FileImpact(
                path: path,
                reason: "Importer must rewrite paths after \(oldPath) → \(newPath)",
                updateType: "rewrite-import-path",
                requiresModelIntervention: false,
            )
        }

        return ImpactReport(symbol: oldPath, changeType: "file-move", files: impacts)
    }

    private func analyzeSymbolRename(name: String, file: URL, graph: DependencyGraph) -> ImpactReport {
        let anchor = graph.relativePath(for: file)
        let impacted = graph.trackedRelativePaths.filter { path in
            guard path != anchor else {
                return false
            }
            guard let record = graph.dependencyRecord(for: path) else {
                return false
            }
            return record.imports.contains { ref in
                ref.symbols.contains(name)
            }
        }

        let impacts = impacted.map { path -> ImpactReport.FileImpact in
            ImpactReport.FileImpact(
                path: path,
                reason: "References symbol \(name) originating near \(anchor)",
                updateType: "rename-symbol",
                requiresModelIntervention: true,
            )
        }

        return ImpactReport(symbol: name, changeType: "symbol-rename", files: impacts)
    }

    private func analyzeProps(component: String, file: URL, graph: DependencyGraph) -> ImpactReport {
        let anchor = graph.relativePath(for: file)
        let impacted = graph.trackedRelativePaths.filter { path in
            guard path != anchor else {
                return false
            }
            guard let record = graph.dependencyRecord(for: path) else {
                return false
            }
            let mentionsComponent = record.imports.contains { ref in
                ref.modulePath.lowercased().contains(component.lowercased())
            }
            let templateHit = record.templateComponents.contains { $0 == component }
            return mentionsComponent || templateHit
        }

        let impacts = impacted.map { path -> ImpactReport.FileImpact in
            ImpactReport.FileImpact(
                path: path,
                reason: "Consumes component \(component) declared near \(anchor)",
                updateType: "patch-component-usage",
                requiresModelIntervention: true,
            )
        }

        return ImpactReport(symbol: component, changeType: "props-change", files: impacts)
    }

    private func analyzeDeletion(at: URL, graph: DependencyGraph) -> ImpactReport {
        let anchor = graph.relativePath(for: at)
        let dependents = graph.subgraphIncomingClosure(from: [anchor]).filter { $0 != anchor }
        let impacts = dependents.map { path -> ImpactReport.FileImpact in
            ImpactReport.FileImpact(
                path: path,
                reason: "Imported deleted artifact \(anchor)",
                updateType: "remove-or-replace-import",
                requiresModelIntervention: true,
            )
        }
        return ImpactReport(symbol: anchor, changeType: "file-delete", files: impacts)
    }
}

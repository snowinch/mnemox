import XCTest

@testable import mnemox

final class CoreTests: XCTestCase {
    func testProjectScannerDetectsNextStackAndHashesSources() async throws {
        let root = try makeScratchDirectory()

        try """
        {
          "dependencies": { "react": "^18.0.0", "next": "^14.0.0" }
        }
        """.write(to: root.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        try Data("{}".utf8).write(to: root.appendingPathComponent("next.config.js"))

        try """
        import { helper } from './helper'

        export const Page = () => helper()
        """.write(to: root.appendingPathComponent("app.tsx"), atomically: true, encoding: .utf8)

        try """
        export const helper = () => 'ok'
        """.write(to: root.appendingPathComponent("helper.ts"), atomically: true, encoding: .utf8)

        let snapshot = try await ProjectScanner().scan(root: root)

        XCTAssertTrue(snapshot.agentPlan.target.contains(root.path))
        XCTAssertTrue(ProjectScanner.detectFrameworks(root: root).contains("next"))
        XCTAssertTrue(snapshot.files.contains(where: { $0.relativePath == "app.tsx" }))
        XCTAssertTrue(snapshot.files.contains(where: { $0.relativePath == "helper.ts" }))
        XCTAssertTrue(snapshot.files.allSatisfy { $0.sha256.count == 64 })

        guard let conventionsWire = snapshot.mxfLog.first else {
            return XCTFail("Expected conventions MXF log fragment")
        }
        XCTAssertTrue(conventionsWire.contains("@next"))
    }

    func testDependencyGraphMapsImportsBidirectionally() async throws {
        let root = try makeScratchDirectory()
        try """
        export const shared = 1
        """.write(to: root.appendingPathComponent("shared.ts"), atomically: true, encoding: .utf8)

        try """
        import { shared } from './shared'
        export const useShared = shared + 1
        """.write(to: root.appendingPathComponent("consumer.ts"), atomically: true, encoding: .utf8)

        let snapshot = try await ProjectScanner().scan(root: root)
        let graph = try await DependencyGraph.build(from: snapshot)

        XCTAssertFalse(graph.encodeToMXF().isEmpty)

        let consumerURL = root.appendingPathComponent("consumer.ts")
        let dependencyTargets = graph.dependencies(of: consumerURL).map(\.path).sorted()
        XCTAssertEqual(dependencyTargets, ["shared.ts"])

        let sharedURL = root.appendingPathComponent("shared.ts")
        let dependentURLs = graph.dependents(of: sharedURL).map(\.path).sorted()
        XCTAssertEqual(dependentURLs.map { URL(fileURLWithPath: $0).lastPathComponent }, ["consumer.ts"])

        let impact = graph.impactOf(changing: sharedURL)
        XCTAssertEqual(impact.symbol, "shared.ts")
        XCTAssertTrue(impact.files.contains(where: { $0.path == "consumer.ts" }))
    }

    func testConventionProfilerHonoursTwentyFiveTokenMXFCap() async throws {
        let root = try makeScratchDirectory()
        try """
        {
          "dependencies": { "vue": "^3.5.0", "vitest": "^1.0.0" },
          "devDependencies": { "@vitejs/plugin-vue": "^5.0.0" }
        }
        """.write(to: root.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        try Data().write(to: root.appendingPathComponent("tailwind.config.ts"))
        try """
        {
          "compilerOptions": { "strict": true, "paths": { "@/*": ["./src/*"] } }
        }
        """.write(to: root.appendingPathComponent("tsconfig.json"), atomically: true, encoding: .utf8)

        try """
        export const x = 1
        """.write(to: root.appendingPathComponent("main.ts"), atomically: true, encoding: .utf8)

        let snapshot = try await ProjectScanner().scan(root: root)
        let profile = try await ConventionProfiler().profile(root: root, snapshot: snapshot)

        XCTAssertLessThanOrEqual(MXFTokenCounter.count(profile.encodeToMXF()), 25)
    }

    func testImpactAnalyzerSurfacesRenamesAndMoves() async throws {
        let root = try makeScratchDirectory()

        try """
        export const foo = 1
        """.write(to: root.appendingPathComponent("lib.ts"), atomically: true, encoding: .utf8)

        try """
        import { foo } from './lib'
        export const bar = foo + 1
        """.write(to: root.appendingPathComponent("main.ts"), atomically: true, encoding: .utf8)

        let snapshot = try await ProjectScanner().scan(root: root)
        let graph = try await DependencyGraph.build(from: snapshot)

        let analyzer = ImpactAnalyzer()

        let renameReport = try await analyzer.analyze(
            change: .symbolRename(name: "foo", file: root.appendingPathComponent("lib.ts")),
            in: graph,
        )

        XCTAssertTrue(renameReport.files.contains(where: { $0.path == "main.ts" }))

        let moveReport = try await analyzer.analyze(
            change: .fileMove(from: root.appendingPathComponent("lib.ts"), to: root.appendingPathComponent("legacy/lib.ts")),
            in: graph,
        )

        XCTAssertTrue(moveReport.files.contains(where: { $0.path == "main.ts" }))
        let rewriteImpacts = moveReport.files.filter { $0.updateType == "rewrite-import-path" }
        XCTAssertTrue(rewriteImpacts.allSatisfy { $0.requiresModelIntervention == false })
    }

    func testPreFlightSystemBlocksAmbiguityAndInternationalization() async throws {
        let emptyGraph = DependencyGraph(
            rootPath: "/tmp",
            nodes: [:],
            outgoing: [:],
            incoming: [:],
        )

        let ambiguousTask = UserTask(detail: "Add hero component with animations")
        let ambiguityResult = try await PreFlightSystem().run(task: ambiguousTask, graph: emptyGraph, conventions: ConventionProfile(frameworkTags: [], ruleLines: []))
        XCTAssertFalse(ambiguityResult.passed)
        XCTAssertEqual(ambiguityResult.blockingCheck, .ambiguityGuard)

        let conventions = ConventionProfile(
            frameworkTags: ["@nuxt"],
            ruleLines: ["i18n[@nuxtjs/i18n] ->locales REQUIRED"],
        )

        let i18nTask = UserTask(detail: "Inject copy \"Welcome aboard\" into dashboard")
        let i18nResult = try await PreFlightSystem().run(task: i18nTask, graph: emptyGraph, conventions: conventions)
        XCTAssertFalse(i18nResult.passed)
        XCTAssertEqual(i18nResult.blockingCheck, .i18nGuard)
    }

    func testTaskDecomposerProducesAtomicMXFContextsUnderBudget() async throws {
        let root = try makeScratchDirectory()

        try """
        export const base = 1
        """.write(to: root.appendingPathComponent("alpha.ts"), atomically: true, encoding: .utf8)

        try """
        import { base } from './alpha'
        export const derived = base + 2
        """.write(to: root.appendingPathComponent("beta.ts"), atomically: true, encoding: .utf8)

        let snapshot = try await ProjectScanner().scan(root: root)
        let graph = try await DependencyGraph.build(from: snapshot)

        let conventions = ConventionProfile(frameworkTags: ["@ts"], ruleLines: ["style:auto"])
        let plan = try await TaskDecomposer().decompose(
            task: UserTask(detail: "Refactor beta.ts import graph"),
            graph: graph,
            conventions: conventions,
        )

        XCTAssertFalse(plan.steps.isEmpty)

        for step in plan.steps {
            XCTAssertEqual(step.agentCode, "WRITE")
            let payload = Data(step.directive.utf8)
            let atomic = try JSONDecoder().decode(AtomicTask.self, from: payload)
            XCTAssertLessThanOrEqual(MXFTokenCounter.count(atomic.mxfContext), 300)
        }
    }

    func testSnapshotManagerPreservesContentsAcrossRestore() async throws {
        let root = try makeScratchDirectory()

        try """
        export const version = 'alpha'
        """.write(to: root.appendingPathComponent("tracked.ts"), atomically: true, encoding: .utf8)

        let manager = SnapshotManager()
        let snapshot = try await manager.createSnapshot(root: root)

        try """
        export const version = 'beta'
        """.write(to: root.appendingPathComponent("tracked.ts"), atomically: true, encoding: .utf8)

        try await manager.restore(snapshot: snapshot)

        let restored = try String(contentsOf: root.appendingPathComponent("tracked.ts"))
        XCTAssertTrue(restored.contains("alpha"))

        let listed = manager.listSnapshots(root: root)
        XCTAssertTrue(listed.contains(where: { $0.id == snapshot.id }))

        try await manager.deleteSnapshot(snapshot)
        let afterDelete = manager.listSnapshots(root: root)
        XCTAssertFalse(afterDelete.contains(where: { $0.id == snapshot.id }))
    }

    func testImpactMXFEnvelopePassesStructuralValidator() throws {
        let report = ImpactReport(
            symbol: "sample.ts",
            changeType: "edit",
            files: [
                ImpactReport.FileImpact(
                    path: "downstream.ts",
                    reason: "Matches bracket ] safely",
                    updateType: "rewrite-import-path",
                    requiresModelIntervention: false,
                ),
            ],
        )

        XCTAssertEqual(MXFValidator.validate(report.encodeToMXF()), .valid)
    }

    private func makeScratchDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mnemox-core-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

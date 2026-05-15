import XCTest
@testable import mnemox

final class ModelInterfaceTests: XCTestCase {
    func testPromptEngineHonorsTokenBudgetsAndTrimsLowValueDependencies() throws {
        let conventions = ConventionProfile(
            frameworkTags: (0 ..< 48).map { "@tag\($0)-payload-with-extra-chars" },
            ruleLines: ["style:tailwind-only NO-inline"],
        )

        func dependency(path: String, tier: Int) -> FileDependency {
            FileDependency(
                path: path,
                framework: tier == 0 ? "swift" : nil,
                imports: tier == 0 ? [
                    FileDependency.ImportRef(modulePath: "Core", symbols: ["PrimarySymbol", "SecondarySymbol"]),
                ] : [
                    FileDependency.ImportRef(modulePath: "Support", symbols: ["S\(tier)"]),
                ],
                autoSymbols: tier == 0 ? ["useTelemetry", "useMetrics"] : [],
                templateComponents: tier == 0 ? ["MainScaffold", "DetailScaffold"] : [],
            )
        }

        var dependencies: [FileDependency] = []
        dependencies.append(dependency(path: "app/PrimaryTarget.swift", tier: 0))
        for tier in 1 ... 18 {
            dependencies.append(dependency(path: "support/Noise\(tier)Layer.swift", tier: tier))
        }

        let task = AtomicTask(
            targetFile: "app/PrimaryTarget.swift",
            action: "rename-symbol",
            mxfContext: String(repeating: "SHARD ", count: 420),
        )

        let prompt = try PromptEngine.build(task: task, conventions: conventions, context: dependencies)

        XCTAssertLessThanOrEqual(MXFTokenCounter.count(prompt.system), PromptEngine.systemTokenCeiling)
        XCTAssertLessThanOrEqual(MXFTokenCounter.count(prompt.context), PromptEngine.contextTokenCeiling)
        XCTAssertLessThanOrEqual(MXFTokenCounter.count(prompt.task), PromptEngine.atomicTaskTokenCeiling)
        XCTAssertLessThanOrEqual(MXFTokenCounter.count(prompt.outputContract), PromptEngine.outputContractCeiling)

        let aggregate = PromptEngine.cumulativeTokenEstimate(for: prompt)
        XCTAssertLessThanOrEqual(
            aggregate,
            PromptEngine.cumulativePromptCeiling,
            "Mnemox aggregates must stay under the 400 mnemonic token guard.",
        )

        XCTAssertTrue(
            prompt.context.contains("app/PrimaryTarget.swift"),
            "High-salience primary files survive dependency trimming.",
        )
        XCTAssertLessThan(prompt.temperature, 0.2)
        XCTAssertEqual(prompt.maxTokens, 100)
    }

    func testResponseParserRemovesMarkdownFences() throws {
        let prose = ModelResponse(
            content: """
            Explanation before fence

            ```swift
            enum Sample {
              case wired
            }
            ```

            Trailing chatter
            """,
            tokensUsed: 12,
            finishReason: .stop,
            durationMs: 4,
        )

        let contract = OutputContract(language: "swift", targetFile: "Sources/Demo.swift")
        let result = try ResponseParser.parse(prose, expected: contract)

        XCTAssertFalse(result.code.contains("```"))
        XCTAssertTrue(result.code.contains("enum Sample"))
        XCTAssertTrue(result.validationHints.contains("stripped-fence"))
        XCTAssertTrue(result.isComplete)
    }

    func testResponseParserDetectsIncompleteLengthTerminatedStreams() throws {
        let halted = ModelResponse(
            content: "```ts\npartial code\n```",
            tokensUsed: 64,
            finishReason: .length,
            durationMs: 8,
        )

        let contract = OutputContract(language: "typescript", targetFile: "web/module.ts")
        let result = try ResponseParser.parse(halted, expected: contract)

        XCTAssertFalse(result.isComplete)
        XCTAssertTrue(result.validationHints.contains("finish-reason-length"))
        XCTAssertFalse(result.code.contains("```"))
    }
}

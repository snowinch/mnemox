import XCTest
@testable import mnemox

final class MXFTests: XCTestCase {
    func testRoundTripFileDependencyMatchesAGENTSExampleShape() throws {
        let specimen = FileDependency(
            path: "pages/index.vue",
            framework: "nuxt",
            imports: [
                FileDependency.ImportRef(modulePath: "constants", symbols: ["CLIENT_LOGOS", "COMPANY", "portfolioCaseHomeImage"]),
                FileDependency.ImportRef(modulePath: "types/home", symbols: ["CaseEntry", "FaqItem"]),
            ],
            autoSymbols: ["useI18n", "useHead", "definePageMeta"],
            templateComponents: ["SectionHero", "SectionClientLogos"],
        )

        try assertCycle(specimen)
    }

    func testRoundTripComponentInterfaceMatchesAGENTSExampleShape() throws {
        let specimen = ComponentInterface(
            path: "sections/SectionHero.vue",
            framework: "vue",
            props: [
                ComponentInterface.Prop(name: "badge", abbreviatedType: "str", optionality: .optional, defaultValue: nil),
                ComponentInterface.Prop(name: "title", abbreviatedType: "str", optionality: .required, defaultValue: nil),
                ComponentInterface.Prop(name: "subtitle", abbreviatedType: "str", optionality: .required, defaultValue: nil),
            ],
            relationalTargets: ["UiCta", "useI18n"],
        )

        try assertCycle(specimen)
    }

    func testRoundTripExecutionPlanUsesOrderedSteps() throws {
        let specimen = ExecutionPlan(
            action: "add-prop",
            target: "SectionHero.description",
            steps: [
                ExecutionPlan.Step(number: 1, agentCode: "SCAN", directive: "->usages[SectionHero] ->affected[]"),
                ExecutionPlan.Step(number: 2, agentCode: "WRITE", directive: "+prop(description?:str)"),
            ],
        )

        try assertCycle(specimen)
    }

    func testRoundTripConventionProfileTracksTagLineAndRules() throws {
        let specimen = ConventionProfile(
            frameworkTags: ["@nuxt4", "@ts-strict"],
            ruleLines: [
                "i18n[@nuxtjs/i18n it,en] ->locales/*.ts REQUIRED",
                "components:auto ~/components no-prefix",
            ],
        )

        try assertCycle(specimen)
    }

    func testRoundTripAgentMessagePreservesPayloadMetadata() throws {
        let specimenID = try XCTUnwrap(UUID(uuidString: "aaaaaaaa-bbbb-4ccc-dddd-eeeeeeeeeeee"))
        let corr = try XCTUnwrap(UUID(uuidString: "aaaaaaaa-bbbb-4ccc-dddd-eeeeffffff01"))

        let clock = Date(timeIntervalSince1970: 1_700_000_000)

        let envelope = AgentMessage(
            id: specimenID,
            from: "main",
            to: "writer",
            kind: .taskAssignment,
            payload: """
            PLAN:add-prop/SectionHero.description
              WRITE #sections/SectionHero.vue +prop(description?:str)
            """,
            timestamp: clock,
            correlationID: corr,
        )

        try assertCycle(envelope)

        XCTAssertEqual(MXFValidator.validateMessage(envelope), .valid)
    }

    func testValidatorSurfacesStructuralIssuesWithCoordinates() throws {
        let verdict = MXFValidator.validate("PLAN:broken")

        guard case let .invalid(issues) = verdict else {
            return XCTFail("Expected PLAN without slash to invalidate")
        }

        guard let first = issues.first else {
            return XCTFail("Expected at least one validation issue")
        }

        XCTAssertGreaterThanOrEqual(first.line, 1)
        XCTAssertGreaterThanOrEqual(first.column, 1)
        XCTAssert(first.message.isEmpty == false)
    }

    func testTokenCounterUsesFourCharacterHeuristicAndBatchSum() throws {
        XCTAssertEqual(MXFTokenCounter.count("abcd"), 1)
        XCTAssertEqual(MXFTokenCounter.count(String(repeating: "x", count: 9)), 3)
        XCTAssertTrue(MXFTokenCounter.exceedsLimit("abcd", limit: 0))

        let clock = Date(timeIntervalSince1970: 1_700_000_000)
        let left = AgentMessage(id: UUID(), from: "a", to: "b", kind: .progressUpdate, payload: "abc", timestamp: clock, correlationID: nil)
        let right = AgentMessage(id: UUID(), from: "c", to: "d", kind: .progressUpdate, payload: "abc", timestamp: clock, correlationID: nil)

        let combined = MXFTokenCounter.count([left, right])
        let expected = MXFTokenCounter.count(MXFEncoder.encode(left)) + MXFTokenCounter.count(MXFEncoder.encode(right))

        XCTAssertEqual(combined, expected)
    }

    func testMXFDecodeProducesPlanGraph() throws {
        let specimen = ExecutionPlan(
            action: "add-prop",
            target: "SectionHero.description",
            steps: [
                ExecutionPlan.Step(number: 1, agentCode: "SCAN", directive: "-"),
            ],
        )

        let node = try MXFDecoder.decode(MXFEncoder.encode(specimen))
        XCTAssertEqual(node.type, .plan)
        XCTAssertEqual(node.identifier, "\(specimen.action)/\(specimen.target)")
    }

    private func assertCycle(_ model: FileDependency) throws {
        let wire = MXFEncoder.encode(model)
        let rebuilt = try MXFDecoder.decodeFileDependency(wire)
        XCTAssertEqual(rebuilt, model)
        XCTAssertEqual(MXFValidator.validate(wire), .valid)
    }

    private func assertCycle(_ model: ComponentInterface) throws {
        let wire = MXFEncoder.encode(model)
        let rebuilt = try MXFDecoder.decodeComponentInterface(wire)
        XCTAssertEqual(rebuilt, model)
        XCTAssertEqual(MXFValidator.validate(wire), .valid)
    }

    private func assertCycle(_ model: ExecutionPlan) throws {
        let wire = MXFEncoder.encode(model)
        let rebuilt = try MXFDecoder.decodeExecutionPlan(wire)
        XCTAssertEqual(rebuilt, model)
        XCTAssertEqual(MXFValidator.validate(wire), .valid)
    }

    private func assertCycle(_ model: ConventionProfile) throws {
        let wire = MXFEncoder.encode(model)
        let rebuilt = try MXFDecoder.decodeConventionProfile(wire)
        XCTAssertEqual(rebuilt, model)
        XCTAssertEqual(MXFValidator.validate(wire), .valid)
    }

    private func assertCycle(_ model: AgentMessage) throws {
        let wire = MXFEncoder.encode(model)
        let rebuilt = try MXFDecoder.decodeAgentMessage(wire)
        XCTAssertEqual(rebuilt, model)
        XCTAssertEqual(MXFValidator.validate(wire), .valid)
    }
}

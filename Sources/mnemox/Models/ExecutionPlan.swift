import Foundation

/// Ordered agent checklist describing how executors should mutate the repository for one user goal.
public struct ExecutionPlan: Codable, Equatable, Sendable {
    public struct Step: Codable, Equatable, Sendable {
        public var number: Int
        public var agentCode: String
        public var directive: String

        public init(number: Int, agentCode: String, directive: String) {
            self.number = number
            self.agentCode = agentCode
            self.directive = directive
        }
    }

    public var action: String
    public var target: String
    public var steps: [Step]

    public init(action: String, target: String, steps: [Step]) {
        self.action = action
        self.target = target
        self.steps = steps
    }

    /// Serializes MainAgent decompositions into `PLAN:` MXF rows consumable by workers.
    public func encodeToMXF() -> String {
        MXFEncoder.encode(self)
    }
}

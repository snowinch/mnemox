import Foundation

/// Declares a UI/API surface (props plus relational emits) distilled from parsers for Planner agents.
public struct ComponentInterface: Codable, Equatable, Sendable {
    public enum OptionalityMarker: String, Codable, Sendable {
        case required
        case optional
    }

    public struct Prop: Codable, Equatable, Sendable {
        public var name: String
        /// Abbreviated MXF type literal such as `str` or `num`.
        public var abbreviatedType: String
        public var optionality: OptionalityMarker
        public var defaultValue: String?

        public init(name: String, abbreviatedType: String, optionality: OptionalityMarker, defaultValue: String? = nil) {
            self.name = name
            self.abbreviatedType = abbreviatedType
            self.optionality = optionality
            self.defaultValue = defaultValue
        }
    }

    public var path: String
    public var framework: String?
    public var props: [Prop]
    public var relationalTargets: [String]

    public init(path: String, framework: String? = nil, props: [Prop], relationalTargets: [String]) {
        self.path = path
        self.framework = framework
        self.props = props
        self.relationalTargets = relationalTargets
    }

    /// Encodes Vue/SwiftUI-style component contracts into Mnemox `props[...]` blocks.
    public func encodeToMXF() -> String {
        MXFEncoder.encode(self)
    }
}

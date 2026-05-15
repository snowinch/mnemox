import Foundation

/// High-level discriminators describing reconstructed Mnemox Format trees independent of parsers.
public enum MXFNodeType: String, Codable, CaseIterable, Sendable {
    case file
    case symbol
    case props
    case plan
    case convention
    case impact
    case message
}

/// Directed edge between Mnemox graph nodes labelled with abbreviated MXF operator semantics.
public struct MXFRelationship: Codable, Equatable, Sendable {
    public var operation: MXFOperator
    public var target: String
    public var cardinality: MXFCardinality

    public init(operation: MXFOperator, target: String, cardinality: MXFCardinality) {
        self.operation = operation
        self.target = target
        self.cardinality = cardinality
    }
}

/// Enumerates mnemonic operators surfaced in Mnemox relationship lines (<-, ->, props, tmpl, ...).
public enum MXFOperator: String, Codable, CaseIterable, Sendable {
    case produces = "->"
    case depends = "<-"
    case emits = "~>"
    case implements = "=>"
    case belongsTo = "::"
}

/// Describes cardinality placeholders for relational metadata stored with MXF nodes.
public enum MXFCardinality: String, Codable, CaseIterable, Sendable {
    case zeroOrOne = "0..1"
    case oneOrMany = "1..n"
}

/// Recursive AST reflecting indented Mnemox Format documents prior to hydrating domain structs.
public struct MXFNode: Codable, Equatable, Sendable {
    public var type: MXFNodeType
    public var identifier: String
    public var attributes: [String: String]
    public var children: [MXFNode]
    public var relationships: [MXFRelationship]

    public init(
        type: MXFNodeType,
        identifier: String,
        attributes: [String: String],
        children: [MXFNode],
        relationships: [MXFRelationship]
    ) {
        self.type = type
        self.identifier = identifier
        self.children = children
        self.relationships = relationships
        self.attributes = attributes
    }
}

/// Concrete validation faults carrying human-readable rationale plus deterministic coordinates.
public struct MXFValidationIssue: Codable, Equatable, Sendable {
    public var line: Int
    public var column: Int
    public var message: String

    public init(line: Int, column: Int, message: String) {
        self.line = line
        self.column = column
        self.message = message
    }
}

/// Outcome capturing either structural acceptance or enumerated MXF authoring failures.
public enum ValidationResult: Equatable, Sendable {
    case valid
    case invalid([MXFValidationIssue])
}

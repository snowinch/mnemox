import Foundation

/// Detected framework tags plus rule rows that describe how writers must behave in a repository.
public struct ConventionProfile: Codable, Equatable, Sendable {
    /// Header tokens rendered with `@` prefixes, e.g. `"@nuxt4"`.
    public var frameworkTags: [String]
    /// Remaining deterministic policy rows emitted after the tag line.
    public var ruleLines: [String]

    public init(frameworkTags: [String], ruleLines: [String]) {
        self.frameworkTags = frameworkTags
        self.ruleLines = ruleLines
    }

    /// Exports profiler output as compact Mnemox Format text for PromptEngine overlays.
    public func encodeToMXF() -> String {
        MXFEncoder.encode(self)
    }
}

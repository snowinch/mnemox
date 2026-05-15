import Foundation

/// Symbol-level imports, auto-import macros, and template wiring discovered for one repository file.
public struct FileDependency: Codable, Equatable, Sendable {
    public struct ImportRef: Codable, Equatable, Sendable {
        public var modulePath: String
        public var symbols: [String]

        public init(modulePath: String, symbols: [String]) {
            self.modulePath = modulePath
            self.symbols = symbols
        }
    }

    public var path: String
    public var framework: String?
    public var imports: [ImportRef]
    public var autoSymbols: [String]
    public var templateComponents: [String]

    public init(
        path: String,
        framework: String? = nil,
        imports: [ImportRef],
        autoSymbols: [String],
        templateComponents: [String]
    ) {
        self.path = path
        self.framework = framework
        self.imports = imports
        self.autoSymbols = autoSymbols
        self.templateComponents = templateComponents
    }

    /// Bridges ProjectScanner graphs into deterministic MXF file nodes.
    public func encodeToMXF() -> String {
        MXFEncoder.encode(self)
    }
}

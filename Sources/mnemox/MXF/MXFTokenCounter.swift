import Foundation

/// Cheap token budgeting service approximating Mnemox payload footprint before prompting local models.
public enum MXFTokenCounter {
    private static func approximatesTokens(forScalars scalarCount: Int) -> Int {
        guard scalarCount > 0 else { return 0 }
        return (scalarCount + 3) / 4
    }

    /// Estimates mnemonic byte length using a deterministic 4:1 heuristic for Phase 1 budgeting.
    public static func count(_ mxf: String) -> Int {
        approximatesTokens(forScalars: mxf.count)
    }

    /// Sums mnemonic estimates for outbound batch traffic (MessageBus aggregates, bundle prompts, etc.).
    public static func count(_ messages: [AgentMessage]) -> Int {
        messages.reduce(0) { aggregate, envelope in aggregate + MXFTokenCounter.count(MXFEncoder.encode(envelope)) }
    }

    /// Returns true when mnemonic demand exceeds downstream limit checks for local model dispatch guards.
    public static func exceedsLimit(_ mxf: String, limit: Int) -> Bool {
        count(mxf) > limit
    }
}

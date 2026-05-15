import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Chooses concrete specialists while multiplexing one shared [`ModelClient`] lease under RAM pressure.
public actor AgentPool {
    private let sharedClient: ModelClient
    private let graph: DependencyGraph
    private let conventions: ConventionProfile
    private let root: URL

    private var activeAgents = 0
    private var modelLeaseBusy = false
    private var modelWaiters: [CheckedContinuation<Void, Never>] = []

    public init(sharedClient: ModelClient, graph: DependencyGraph, conventions: ConventionProfile, root: URL) {
        self.sharedClient = sharedClient
        self.graph = graph
        self.conventions = conventions
        self.root = root
    }

    public var activeCount: Int {
        activeAgents
    }

    public var memoryPressure: Double {
        get async {
            Self.measureMemoryPressure()
        }
    }

    /// Acquires a worker. Model-backed agents await exclusive lease plus RAM headroom.
    public func acquire(type: AgentType, modelClient _: ModelClient) async throws -> any BaseAgent {
        let agentID = Self.makeAgentIdentifier(for: type)

        if type.requiresExclusiveModelLease {
            await waitWhileUnderMemoryPressure()
            await acquireModelLease()
        }

        activeAgents += 1

        switch type {
        case .scanner:
            return ScannerAgent(id: agentID, root: root, graph: graph)
        case .architect:
            return ArchitectAgent(id: agentID, graph: graph, conventions: conventions, client: sharedClient)
        case .writer:
            return WriterAgent(id: agentID, root: root, graph: graph, conventions: conventions, client: sharedClient)
        case .refactor:
            return RefactorAgent(id: agentID, root: root, graph: graph, conventions: conventions, client: sharedClient)
        case .i18n:
            return I18nAgent(id: agentID, graph: graph, conventions: conventions, client: sharedClient)
        case .test:
            return TestAgent(id: agentID, root: root, graph: graph, conventions: conventions, client: sharedClient)
        case .verifier:
            return VerifierAgent(id: agentID, conventions: conventions)
        }
    }

    public func release(_ agent: any BaseAgent) async {
        activeAgents -= 1

        if agent.type.requiresExclusiveModelLease {
            releaseModelLease()
        }
    }

    private func waitWhileUnderMemoryPressure() async {
        var pressure = await memoryPressure
        while pressure > 0.75 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            pressure = await memoryPressure
        }
    }

    private func acquireModelLease() async {
        if modelLeaseBusy == false {
            modelLeaseBusy = true
            return
        }

        await withCheckedContinuation { continuation in
            modelWaiters.append(continuation)
        }

        modelLeaseBusy = true
    }

    private func releaseModelLease() {
        modelLeaseBusy = false
        if let waiter = modelWaiters.first {
            modelWaiters.removeFirst()
            waiter.resume()
        }
    }

    private nonisolated static func measureMemoryPressure() -> Double {
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else {
            return 0
        }

        #if os(macOS)
            return Self.machMemoryPressure(totalBytes: total)
        #elseif os(iOS) || os(tvOS) || os(watchOS)
            let available = Double(os_proc_available_memory())
            let used = max(0, total - available)
            return min(1, max(0, used / total))
        #else
            return 0
        #endif
    }

    #if os(macOS)
        private nonisolated static func machMemoryPressure(totalBytes: Double) -> Double {
            var stats = vm_statistics64_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

            let kern = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
                }
            }

            guard kern == KERN_SUCCESS else {
                return 0
            }

            let pageSize = Double(vm_kernel_page_size)
            let freePages = Double(stats.free_count + stats.inactive_count)
            let freeBytes = freePages * pageSize
            let used = max(0, totalBytes - freeBytes)

            return min(1, max(0, used / totalBytes))
        }
    #endif

    private nonisolated static func makeAgentIdentifier(for type: AgentType) -> AgentID {
        let suffix = UUID().uuidString.prefix(8)
        return "mnemox.\(type.rawValue).\(suffix)"
    }
}

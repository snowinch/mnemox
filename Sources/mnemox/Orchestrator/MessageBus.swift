import Foundation

private final class SubscriberHandle: @unchecked Sendable {
    let continuation: AsyncStream<AgentMessage>.Continuation

    init(_ continuation: AsyncStream<AgentMessage>.Continuation) {
        self.continuation = continuation
    }
}

/// MXF-first mailbox delivering strictly ordered envelopes per subscriber.
public actor MessageBus {
    private var subscribers: [AgentID: [SubscriberHandle]] = [:]
    private var correlationHistories: [UUID: [AgentMessage]] = [:]

    private let historyCap = 100

    public init() {}

    public func send(_ message: AgentMessage) async {
        if let correlationID = message.correlationID {
            var bucket = correlationHistories[correlationID, default: []]
            bucket.append(message)
            if bucket.count > historyCap {
                bucket.removeFirst(bucket.count - historyCap)
            }
            correlationHistories[correlationID] = bucket
        }

        guard let handles = subscribers[message.to] else {
            return
        }

        for handle in handles {
            handle.continuation.yield(message)
        }
    }

    public func subscribe(agentID: AgentID) -> AsyncStream<AgentMessage> {
        AsyncStream { continuation in
            let handle = SubscriberHandle(continuation)
            Task {
                await self.install(handle: handle, continuation: continuation, agentID: agentID)
            }
        }
    }

    public func history(correlationID: UUID) -> [AgentMessage] {
        correlationHistories[correlationID, default: []]
    }

    public func clear(correlationID: UUID) {
        correlationHistories[correlationID] = nil
    }

    private func install(
        handle: SubscriberHandle,
        continuation: AsyncStream<AgentMessage>.Continuation,
        agentID: AgentID,
    ) async {
        register(handle, agentID: agentID)
        continuation.onTermination = { _ in
            Task {
                await self.unregister(handle, agentID: agentID)
            }
        }
    }

    private func register(_ handle: SubscriberHandle, agentID: AgentID) {
        var bucket = subscribers[agentID, default: []]
        bucket.append(handle)
        subscribers[agentID] = bucket
    }

    private func unregister(_ handle: SubscriberHandle, agentID: AgentID) {
        guard var bucket = subscribers[agentID] else {
            return
        }
        bucket.removeAll { existing in
            ObjectIdentifier(existing) == ObjectIdentifier(handle)
        }
        subscribers[agentID] = bucket.isEmpty ? nil : bucket
    }
}

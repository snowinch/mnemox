import Foundation

/// Reason the local model stopped generating tokens for a completion.
public enum FinishReason: String, Sendable, Equatable, Codable {
    case stop
    case length
    case error
}

/// Incremental payload while streaming chat completions.
public struct ModelChunk: Sendable, Equatable {
    public var text: String
    public var finishReason: FinishReason?

    public init(text: String, finishReason: FinishReason? = nil) {
        self.text = text
        self.finishReason = finishReason
    }
}

/// Surgical prompt bundle forwarded to OpenAI-compatible local runtimes.
public struct ModelPrompt: Sendable, Equatable {
    public let system: String
    public let context: String
    public let task: String
    public let outputContract: String
    public let temperature: Double
    public let maxTokens: Int

    public init(
        system: String,
        context: String,
        task: String,
        outputContract: String,
        temperature: Double,
        maxTokens: Int,
    ) {
        self.system = system
        self.context = context
        self.task = task
        self.outputContract = outputContract
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

/// Normalized completion metadata returned by [`ModelClient`].
public struct ModelResponse: Sendable, Equatable {
    public let content: String
    public let tokensUsed: Int
    public let finishReason: FinishReason
    public let durationMs: Int

    public init(content: String, tokensUsed: Int, finishReason: FinishReason, durationMs: Int) {
        self.content = content
        self.tokensUsed = tokensUsed
        self.finishReason = finishReason
        self.durationMs = durationMs
    }
}

/// Failure modes when talking to a local model endpoint.
public enum ModelError: Error, Sendable, Equatable {
    case unavailable(String)
    case timeout
    case invalidResponse(String)
    case tokenLimitExceeded
}

/// Abstracts any local OpenAI-compatible chat runtime (vLLM-mlx, Ollama, etc.).
public protocol ModelClient: Sendable {
    var modelID: String { get }
    var isAvailable: Bool { get async }
    func complete(prompt: ModelPrompt) async throws -> ModelResponse
    func stream(prompt: ModelPrompt) -> AsyncThrowingStream<ModelChunk, Error>
}

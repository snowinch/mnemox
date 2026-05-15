import Foundation

/// `ModelClient` adapter for Ollama’s OpenAI-compatible `/v1/chat/completions` bridge on `localhost:11434`.
public struct OllamaClient: ModelClient {
    private let runtime: LocalOpenAIModelRuntimeConfiguration
    private let transport: URLSessionCarrier

    public var modelID: String {
        runtime.modelIdentifier
    }

    public init(runtime: LocalOpenAIModelRuntimeConfiguration) {
        self.runtime = runtime
        transport = URLSessionCarrier(session: LocalOpenAIModelRuntimeConfiguration.ephemeralSession(
            forTimeout: runtime.requestTimeoutSeconds,
        ))
    }

    /// Reuses Mnemox’ default quantized coder tag so orchestration swaps only the transport hostname.
    public init() throws {
        try self.init(
            runtime: LocalOpenAIModelRuntimeConfiguration(
                modelIdentifier: LocalOpenAIModelRuntimeConfiguration.defaultVllmMLXModelID,
                chatCompletionsURL: LocalOpenAIModelRuntimeConfiguration.defaultOllamaChatURL(),
                requestTimeoutSeconds: 120,
            ),
        )
    }

    public var isAvailable: Bool {
        get async {
            await OpenAIRuntimeTransport.probeAvailability(carrier: transport, chatEndpoint: runtime.chatCompletionsURL)
        }
    }

    public func complete(prompt: ModelPrompt) async throws -> ModelResponse {
        let checkpoint = Date()
        return try await OpenAIRuntimeTransport.postNonStreaming(
            carrier: transport,
            prompt: prompt,
            endpoint: runtime.chatCompletionsURL,
            modelIdentifier: runtime.modelIdentifier,
            startedReference: checkpoint,
        )
    }

    public func stream(prompt: ModelPrompt) -> AsyncThrowingStream<ModelChunk, Error> {
        OpenAIRuntimeTransport.streamingStream(
            carrier: transport,
            prompt: prompt,
            endpoint: runtime.chatCompletionsURL,
            modelIdentifier: runtime.modelIdentifier,
        )
    }
}

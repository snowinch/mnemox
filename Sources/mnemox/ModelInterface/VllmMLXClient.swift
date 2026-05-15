import Foundation

/// `ModelClient` adapter targeting the MLX-optimized [`vLLM`](https://github.com/ml-explore/mlx-examples) `/v1` surface.
public struct VllmMLXClient: ModelClient {
    private let runtime: LocalOpenAIModelRuntimeConfiguration
    private let transport: URLSessionCarrier

    public var modelID: String {
        runtime.modelIdentifier
    }

    /// Initializes with an explicit MLX runtime profile (defaults bundled for local Qwen Coder quantization).
    public init(runtime: LocalOpenAIModelRuntimeConfiguration) {
        self.runtime = runtime
        transport = URLSessionCarrier(session: LocalOpenAIModelRuntimeConfiguration.ephemeralSession(
            forTimeout: runtime.requestTimeoutSeconds,
        ))
    }

    /// Convenience wiring to `localhost:8000` with Mnemox’ documented default model artifact.
    public init() throws {
        try self.init(
            runtime: LocalOpenAIModelRuntimeConfiguration(
                modelIdentifier: LocalOpenAIModelRuntimeConfiguration.defaultVllmMLXModelID,
                chatCompletionsURL: LocalOpenAIModelRuntimeConfiguration.defaultVllmMLXChatURL(),
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

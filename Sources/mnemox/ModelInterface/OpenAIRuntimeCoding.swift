import Foundation

// Codable payloads, budget markers, and OpenAI-compatible response shaping for ModelInterface transports.

enum PromptSectionMarkers {
    static let contextOpening = "[CONTEXT]"
    static let taskOpening = "[TASK]"
    static let contractOpening = "[OUTPUT_CONTRACT]"
}

/// Runtime endpoint configuration reused by MLX and Ollama adapters.
public struct LocalOpenAIModelRuntimeConfiguration: Sendable, Equatable {
    public var modelIdentifier: String
    public var chatCompletionsURL: URL
    /// Request timeout budget for outbound `/v1/chat/completions` calls.
    public var requestTimeoutSeconds: TimeInterval

    public init(modelIdentifier: String, chatCompletionsURL: URL, requestTimeoutSeconds: TimeInterval = 120) {
        self.modelIdentifier = modelIdentifier
        self.chatCompletionsURL = chatCompletionsURL
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }

    public static let defaultVllmMLXModelID = "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"

    public static func defaultVllmMLXChatURL() throws -> URL {
        try makeHTTPURL(host: "localhost", port: 8000, path: "/v1/chat/completions")
    }

    public static func defaultOllamaChatURL() throws -> URL {
        try makeHTTPURL(host: "localhost", port: 11434, path: "/v1/chat/completions")
    }

    static func ephemeralSession(forTimeout seconds: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = seconds
        configuration.timeoutIntervalForResource = seconds
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    private static func makeHTTPURL(host: String, port: Int, path: String) throws -> URL {
        var pieces = URLComponents()
        pieces.scheme = "http"
        pieces.host = host
        pieces.port = port
        pieces.path = path
        guard let resolved = pieces.url else {
            throw ModelError.invalidResponse("Malformed local endpoint URL.")
        }
        return resolved
    }
}

enum OpenAIChatCoding {
    enum Role: String, Encodable {
        case system
        case user
        case assistant
    }

    struct ChatMessage: Encodable {
        var role: Role
        var content: String
    }

    struct ChatRequestBody: Encodable {
        var model: String
        var messages: [ChatMessage]
        var temperature: Double
        var max_tokens: Int
        var stream: Bool
    }

    struct ChoiceEnvelope: Decodable {
        struct MessageBlob: Decodable {
            var role: String?
            var content: String?
        }

        struct DeltaBlob: Decodable {
            var content: String?
        }

        struct ChoiceCore: Decodable {
            var message: MessageBlob?
            var delta: DeltaBlob?
            var finish_reason: String?
        }

        struct UsageBlob: Decodable {
            var prompt_tokens: Int?
            var completion_tokens: Int?
            var total_tokens: Int?
        }

        var choices: [ChoiceCore]
        var usage: UsageBlob?
    }

    static func mapFinishReason(_ raw: String?) -> FinishReason {
        guard let raw else {
            return .stop
        }
        switch raw.lowercased() {
        case "stop", "completed":
            return .stop
        case "length":
            return .length
        default:
            return .error
        }
    }

    static func buildUserPayload(prompt: ModelPrompt) -> String {
        """
        \(PromptSectionMarkers.contextOpening)
        \(prompt.context)

        \(PromptSectionMarkers.taskOpening)
        \(prompt.task)

        \(PromptSectionMarkers.contractOpening)
        \(prompt.outputContract)
        """
    }

    static func encodeRequestJSON(prompt: ModelPrompt, modelIdentifier: String, streaming: Bool) throws -> Data {
        let bodyObject = ChatRequestBody(
            model: modelIdentifier,
            messages: [
                ChatMessage(role: .system, content: prompt.system),
                ChatMessage(role: .user, content: buildUserPayload(prompt: prompt)),
            ],
            temperature: prompt.temperature,
            max_tokens: prompt.maxTokens,
            stream: streaming,
        )

        return try JSONEncoder().encode(bodyObject)
    }

    static func deriveTokenUsage(_ usage: ChoiceEnvelope.UsageBlob?, approximationForCompletion: String) -> Int {
        if let total = usage?.total_tokens {
            return max(0, total)
        }
        let promptTokens = max(0, usage?.prompt_tokens ?? 0)
        let completion = usage?.completion_tokens ?? MXFTokenCounter.count(approximationForCompletion)
        return max(0, promptTokens + completion)
    }

    static func modelsListingURL(for chatEndpoint: URL) -> URL {
        guard chatEndpoint.path.hasSuffix("/chat/completions") else {
            return chatEndpoint
        }

        let trimmedSuffix = "/chat/completions"
        let basePath = String(chatEndpoint.path.dropLast(trimmedSuffix.count))
        var components = URLComponents(url: chatEndpoint, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.path = basePath + "/models"
        if let rewritten = components.url {
            return rewritten
        }

        var fallbackComponents = URLComponents()
        fallbackComponents.scheme = chatEndpoint.scheme
        fallbackComponents.host = chatEndpoint.host
        fallbackComponents.port = chatEndpoint.port
        fallbackComponents.path = basePath + "/models"
        return fallbackComponents.url ?? chatEndpoint
    }

    /// Attempts `/v1/models` derivation; mirrors OpenAI-compatible serving stacks.
    static func buildAvailabilityProbe(from chatEndpoint: URL) -> URL {
        modelsListingURL(for: chatEndpoint)
    }
}

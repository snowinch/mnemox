import Foundation

// URLSession actor plus OpenAI-compatible POST / SSE streaming transports.

actor URLSessionCarrier {
    nonisolated private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await session.bytes(for: request)
    }
}

private enum SSEStreamSignal: Error {
    case receivedDoneSentinel
}

enum OpenAIRuntimeTransport {

    static func postNonStreaming(
        carrier: URLSessionCarrier,
        prompt: ModelPrompt,
        endpoint: URL,
        modelIdentifier: String,
        startedReference: Date,
    ) async throws -> ModelResponse {
        let payload = try OpenAIChatCoding.encodeRequestJSON(
            prompt: prompt,
            modelIdentifier: modelIdentifier,
            streaming: false,
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payloadData: Data
        let rawResponse: URLResponse
        do {
            (payloadData, rawResponse) = try await carrier.data(for: request)
        } catch {
            throw TransportErrorRouter.mapTransportError(error, endpointDisplay: endpoint.absoluteString)
        }

        guard let http = rawResponse as? HTTPURLResponse else {
            throw ModelError.invalidResponse("Missing HTTP envelope.")
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let excerpt = String(data: payloadData, encoding: .utf8) ?? "<binary body>"
            throw ModelError.invalidResponse("HTTP \(http.statusCode): \(excerpt.prefix(280))")
        }

        let parsed = try JSONDecoder().decode(OpenAIChatCoding.ChoiceEnvelope.self, from: payloadData)
        guard let first = parsed.choices.first else {
            throw ModelError.invalidResponse("OpenAI-compatible payload lacked choices[].")
        }

        let assistantText = first.message?.content ?? ""
        let finish = OpenAIChatCoding.mapFinishReason(first.finish_reason)
        let tokens = OpenAIChatCoding.deriveTokenUsage(parsed.usage, approximationForCompletion: assistantText)

        let durationMilliseconds = Int(Date().timeIntervalSince(startedReference) * 1000)
        return ModelResponse(
            content: assistantText,
            tokensUsed: tokens,
            finishReason: finish,
            durationMs: max(0, durationMilliseconds),
        )
    }

    static func streamingStream(
        carrier: URLSessionCarrier,
        prompt: ModelPrompt,
        endpoint: URL,
        modelIdentifier: String,
    ) -> AsyncThrowingStream<ModelChunk, Error> {
        AsyncThrowingStream { continuation in
            let boxedTask = Task {
                do {
                    let payload = try OpenAIChatCoding.encodeRequestJSON(
                        prompt: prompt,
                        modelIdentifier: modelIdentifier,
                        streaming: true,
                    )

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.httpBody = payload
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, rawResponse) = try await carrier.bytes(for: request)
                    guard let http = rawResponse as? HTTPURLResponse else {
                        throw ModelError.invalidResponse("Streaming response missing HTTP metadata.")
                    }
                    guard (200 ..< 300).contains(http.statusCode) else {
                        throw ModelError.invalidResponse("Streaming HTTP \(http.statusCode)")
                    }

                    do {
                        try await Self.scanSSE(linesFrom: bytes) { substring in
                            try Self.handleSSEPayloadLine(substring, continuation: continuation)
                        }
                    } catch SSEStreamSignal.receivedDoneSentinel {
                        continuation.finish()
                        return
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: TransportErrorRouter.mapTransportError(error, endpointDisplay: endpoint.absoluteString)
                    )
                }
            }

            continuation.onTermination = { @Sendable _ in boxedTask.cancel() }
        }
    }

    static func probeAvailability(carrier: URLSessionCarrier, chatEndpoint: URL) async -> Bool {
        let derived = OpenAIChatCoding.buildAvailabilityProbe(from: chatEndpoint)
        var request = URLRequest(url: derived)
        request.httpMethod = "GET"
        request.timeoutInterval = 2
        do {
            let (_, raw) = try await carrier.data(for: request)
            guard let http = raw as? HTTPURLResponse else {
                return false
            }
            return (200 ..< 500).contains(http.statusCode)
        } catch {
            return false
        }
    }

    /// Invokes consumer for logical SSE payloads; raises `SSEStreamSignal.receivedDoneSentinel` once `[DONE]` is observed.
    private static func scanSSE(
        linesFrom bytes: URLSession.AsyncBytes,
        consumer: (@Sendable (Substring) throws -> Void),
    ) async throws {
        var buffer = Data()

        for try await byte in bytes {
            guard byte != UInt8(ascii: "\n") else {
                guard buffer.isEmpty == false else {
                    buffer.removeAll(keepingCapacity: true)
                    continue
                }

                let working = buffer
                buffer.removeAll(keepingCapacity: true)

                guard let rendered = String(data: working, encoding: .utf8) else {
                    continue
                }

                if rendered.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.newlines)).isEmpty {
                    continue
                }

                try consumer(Substring(rendered))
                continue
            }

            buffer.append(byte)
        }

        guard buffer.isEmpty == false else {
            return
        }

        guard let trailing = String(data: buffer, encoding: .utf8),
              trailing.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.newlines)).isEmpty == false
        else {
            return
        }

        try consumer(Substring(trailing))
    }

    private static func handleSSEPayloadLine(
        _ substring: Substring,
        continuation: AsyncThrowingStream<ModelChunk, Error>.Continuation,
    ) throws {
        let trimmedLeading = substring.drop(while: { $0.isWhitespace || $0 == "\u{feff}" })

        guard trimmedLeading.hasPrefix("data:") else {
            return
        }

        let afterPrefix = trimmedLeading.dropFirst("data:".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if afterPrefix == "[DONE]" {
            throw SSEStreamSignal.receivedDoneSentinel
        }

        guard let payload = afterPrefix.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(OpenAIChatCoding.ChoiceEnvelope.self, from: payload),
              let choice = envelope.choices.first
        else {
            return
        }

        if let incremental = choice.delta?.content,
           incremental.isEmpty == false
        {
            continuation.yield(ModelChunk(text: incremental, finishReason: nil))
        }

        if let rawReason = choice.finish_reason {
            let mappedReason = OpenAIChatCoding.mapFinishReason(rawReason)
            continuation.yield(ModelChunk(text: "", finishReason: mappedReason))
        }
    }
}

private enum TransportErrorRouter {
    static func mapTransportError(_ error: Error, endpointDisplay: String) -> Error {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return ModelError.timeout
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                return ModelError.unavailable(
                    "Cannot reach \(endpointDisplay): connection refused or host unreachable (\(urlError.localizedDescription))."
                )
            default:
                break
            }
        }

        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain {
            switch nsErr.code {
            case NSURLErrorTimedOut:
                return ModelError.timeout
            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet:
                return ModelError.unavailable(
                    "Cannot reach \(endpointDisplay): connection refused or host unreachable (\(error.localizedDescription))."
                )
            default:
                break
            }
        }

        let message = "\(endpointDisplay): \(error.localizedDescription)"
        let lowered = message.lowercased()
        if lowered.contains("could not connect") || lowered.contains("connection refused") {
            return ModelError.unavailable(
                "Cannot reach \(endpointDisplay): connection refused or host unreachable (\(error.localizedDescription))."
            )
        }

        return ModelError.invalidResponse(message)
    }
}

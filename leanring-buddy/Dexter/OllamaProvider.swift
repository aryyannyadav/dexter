//
//  OllamaProvider.swift
//  leanring-buddy
//

import Combine
import Foundation

enum OllamaProviderError: LocalizedError, Equatable {
    case notReachable
    case modelUnavailable(modelName: String)
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case malformedStreamChunk(String)
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .notReachable:
            return "Dexter can't reach Ollama. Make sure Ollama is running."
        case .modelUnavailable(let modelName):
            if modelName.lowercased().contains("qwen3.5") {
                return "Qwen3.5 9B isn't installed in Ollama."
            }
            return "\(modelName) isn't installed in Ollama. Install it with the Ollama app or CLI."
        case .invalidResponse:
            return "Dexter received an invalid response from Ollama."
        case .httpError(let statusCode, let body):
            return OllamaProviderError.userFacingMessage(forHTTPStatusCode: statusCode, responseBody: body)
        case .malformedStreamChunk:
            return "Dexter couldn't read a streaming response from Ollama."
        case .imageEncodingFailed:
            return "Couldn't prepare the screen for analysis."
        }
    }

    static func userFacingMessage(forHTTPStatusCode statusCode: Int, responseBody: String) -> String {
        let redactedBody = redactedHTTPErrorBody(responseBody)
        if redactedBody.localizedCaseInsensitiveContains("exceed_context_size")
            || redactedBody.localizedCaseInsensitiveContains("context size") {
            return "Couldn't analyze the current screen — the vision request was too large for Ollama's context window. \(redactedBody)"
        }
        if statusCode == 400, !redactedBody.isEmpty {
            return "Ollama returned an error (HTTP 400). \(redactedBody)"
        }
        if !redactedBody.isEmpty {
            return "Ollama returned an error (HTTP \(statusCode)). \(redactedBody)"
        }
        return "Ollama returned an error (HTTP \(statusCode))."
    }

    static func redactedHTTPErrorBody(_ responseBody: String) -> String {
        let trimmedBody = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedBody.count > 280 else { return trimmedBody }
        return String(trimmedBody.prefix(280)) + "…"
    }
}

struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }

    let models: [Model]
}

struct OllamaChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
        let images: [String]?

        init(role: String, content: String, images: [String]? = nil) {
            self.role = role
            self.content = content
            self.images = images?.isEmpty == true ? nil : images
        }
    }

    let model: String
    let messages: [Message]
    let stream: Bool
    /// When set, thinking models (e.g. Qwen 3.5) honor this flag. Omitted when nil (diagnostic/minimal requests).
    let think: Bool?
    let options: OllamaChatRequestOptions?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        try container.encodeIfPresent(think, forKey: .think)
        try container.encodeIfPresent(options, forKey: .options)
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case think
        case options
    }
}

struct OllamaChatRequestOptions: Encodable {
    let num_ctx: Int?
}

struct OllamaChatResponse: Decodable {
    struct Message: Decodable {
        let role: String?
        let content: String?
        let thinking: String?
    }

    let message: Message?
    let done: Bool?
}

struct OllamaStreamChunk: Decodable {
    struct Message: Decodable {
        let role: String?
        let content: String?
        let thinking: String?
    }

    let message: Message?
    let done: Bool?
}

@MainActor
final class OllamaProvider: AIProvider, ObservableObject {
    static let defaultEndpointString = "http://localhost:11434"
    static let defaultModelName = OllamaModelConfiguration.textModelName
    /// Ollama NDJSON streaming (not Claude SSE). When true, uses `stream: true` with `think: false`.
    private static let usesStreamingChatResponses = true
    private static let chatRequestTimeoutInterval: TimeInterval = 300

    let providerName = "Ollama"

    @Published private(set) var connectionStatus: AIProviderConnectionStatus = .unknown

    var endpointDisplayString: String {
        endpointBaseURL.absoluteString
    }

    var configuredModelName: String {
        modelName
    }

    var configuredVisionModelName: String {
        OllamaModelConfiguration.visionModelName
    }

    private var endpointBaseURL: URL
    private var modelName: String
    private let urlSession: URLSession

    init(
        endpointBaseURL: URL = URL(string: OllamaProvider.defaultEndpointString)!,
        modelName: String = OllamaProvider.defaultModelName,
        urlSession: URLSession = .shared
    ) {
        if let storedURL = DexterOllamaSettingsStore.shared.resolvedEndpointURL {
            self.endpointBaseURL = storedURL
        } else {
            self.endpointBaseURL = endpointBaseURL
        }
        self.modelName = modelName
        self.urlSession = urlSession
    }

    func setModelName(_ updatedModelName: String) {
        modelName = updatedModelName
    }

    func applyEndpointURLString(_ endpointURLString: String) {
        let trimmed = endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let resolvedURL = URL(string: trimmed), resolvedURL.scheme != nil else {
            if let fallbackURL = URL(string: "http://\(trimmed)") {
                endpointBaseURL = fallbackURL
            }
            return
        }
        endpointBaseURL = resolvedURL
    }

    func isVisionModelInstalled() async -> Bool {
        do {
            let installedModelNames = try await fetchInstalledModelNames()
            return Self.modelNameIsAvailable(configuredVisionModelName, in: installedModelNames)
        } catch {
            return false
        }
    }

    func refreshConnectionStatus() async {
        connectionStatus = await evaluateConnectionStatus()
    }

    @discardableResult
    func testConnection() async -> AIProviderConnectionStatus {
        let status = await evaluateConnectionStatus()
        connectionStatus = status
        return status
    }

    func streamChat(
        messages: [AIChatMessage],
        resolvedModelName: String? = nil,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> String {
        let activeModelName = resolvedModelName ?? modelName
        let requestStartedAt = Date()

        let status = await evaluateConnectionStatus(forModelName: activeModelName)
        connectionStatus = status

        switch status {
        case .connected:
            break
        case .notConnected:
            throw OllamaProviderError.notReachable
        case .modelUnavailable:
            throw OllamaProviderError.modelUnavailable(modelName: activeModelName)
        case .unknown:
            throw OllamaProviderError.notReachable
        }

        let ollamaMessages = messages.map { message in
            OllamaChatRequest.Message(
                role: message.role.rawValue,
                content: message.content,
                images: message.base64Images.isEmpty ? nil : message.base64Images
            )
        }

        let includesVisionImages = ollamaMessages.contains { message in
            guard let images = message.images else { return false }
            return !images.isEmpty
        }

        let requestModeLabel = includesVisionImages ? "vision" : "text"
        DexterDiagnosticLog.ollama("model=\(activeModelName) mode=\(requestModeLabel) think=false")
        DexterDiagnosticLog.ollama("request prepared (stream: \(Self.usesStreamingChatResponses && !includesVisionImages), vision: \(includesVisionImages))")

        if includesVisionImages {
            logVisionRequestDiagnostics(ollamaMessages: ollamaMessages, activeModelName: activeModelName, stream: false)
        }

        let responseText: String
        if Self.usesStreamingChatResponses && !includesVisionImages {
            responseText = try await performStreamingChat(
                ollamaMessages: ollamaMessages,
                activeModelName: activeModelName,
                onTextChunk: onTextChunk
            )
        } else {
            responseText = try await performNonStreamingChat(
                ollamaMessages: ollamaMessages,
                activeModelName: activeModelName,
                includesVisionImages: includesVisionImages,
                onTextChunk: onTextChunk
            )
        }

        let elapsedSeconds = Date().timeIntervalSince(requestStartedAt)
        DexterDiagnosticLog.ollama("response received in \(String(format: "%.1f", elapsedSeconds))s (\(responseText.count) characters)")
        return responseText
    }

    private func makeChatURLRequest(
        ollamaMessages: [OllamaChatRequest.Message],
        activeModelName: String,
        stream: Bool,
        includesVisionImages: Bool = false
    ) throws -> URLRequest {
        let requestBody = OllamaChatRequest(
            model: activeModelName,
            messages: ollamaMessages,
            stream: stream,
            think: false,
            options: includesVisionImages ? OllamaChatRequestOptions(num_ctx: 8192) : nil
        )

        var urlRequest = URLRequest(url: endpointBaseURL.appendingPathComponent("api/chat"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = Self.chatRequestTimeoutInterval
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        return urlRequest
    }

    private func performNonStreamingChat(
        ollamaMessages: [OllamaChatRequest.Message],
        activeModelName: String,
        includesVisionImages: Bool,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> String {
        let urlRequest = try makeChatURLRequest(
            ollamaMessages: ollamaMessages,
            activeModelName: activeModelName,
            stream: false,
            includesVisionImages: includesVisionImages
        )
        if includesVisionImages {
            DexterVisionTiming.markOllamaHTTPRequestSent()
        }
        DexterDiagnosticLog.ollama("request sent (non-streaming)")

        let (data, urlResponse): (Data, URLResponse)
        do {
            (data, urlResponse) = try await urlSession.data(for: urlRequest)
        } catch let urlError as URLError {
            if includesVisionImages, urlError.code == .timedOut {
                DexterVisionTiming.logTimeout(afterSeconds: Self.chatRequestTimeoutInterval)
            }
            throw mapURLErrorToOllamaProviderError(urlError)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw OllamaProviderError.invalidResponse
        }

        let responseBodyString = String(data: data, encoding: .utf8) ?? ""

        if includesVisionImages {
            DexterVisionTiming.markOllamaHTTPResponseReceived(httpStatus: httpResponse.statusCode)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if includesVisionImages {
                DexterDiagnosticLog.ollamaVision("HTTP \(httpResponse.statusCode) body: \(OllamaProviderError.redactedHTTPErrorBody(responseBodyString))")
                DexterVisionTiming.markResponseParseCompleted(succeeded: false, responseTextLength: 0)
            }
            if httpResponse.statusCode == 404, responseBodyString.localizedCaseInsensitiveContains("not found") {
                throw OllamaProviderError.modelUnavailable(modelName: activeModelName)
            }
            throw OllamaProviderError.httpError(statusCode: httpResponse.statusCode, body: responseBodyString)
        }

        let chatResponse: OllamaChatResponse
        do {
            chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        } catch {
            if includesVisionImages {
                DexterVisionTiming.markResponseParseCompleted(succeeded: false, responseTextLength: 0)
            }
            throw OllamaProviderError.invalidResponse
        }

        let assistantContent = OllamaResponseSanitizer.userFacingAssistantText(
            content: chatResponse.message?.content ?? "",
            separateThinkingField: chatResponse.message?.thinking
        )
        guard !assistantContent.isEmpty else {
            if includesVisionImages {
                DexterVisionTiming.markResponseParseCompleted(succeeded: false, responseTextLength: 0)
            }
            throw OllamaProviderError.invalidResponse
        }

        if includesVisionImages {
            DexterVisionTiming.markResponseParseCompleted(succeeded: true, responseTextLength: assistantContent.count)
        }

        await onTextChunk(assistantContent)
        return assistantContent
    }

    private func performStreamingChat(
        ollamaMessages: [OllamaChatRequest.Message],
        activeModelName: String,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> String {
        let urlRequest = try makeChatURLRequest(
            ollamaMessages: ollamaMessages,
            activeModelName: activeModelName,
            stream: true
        )
        DexterDiagnosticLog.ollama("request sent (streaming)")

        let (byteStream, urlResponse): (URLSession.AsyncBytes, URLResponse)
        do {
            (byteStream, urlResponse) = try await urlSession.bytes(for: urlRequest)
        } catch let urlError as URLError {
            throw mapURLErrorToOllamaProviderError(urlError)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw OllamaProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorBody = ""
            if let errorData = try? await byteStream.collectData(upTo: 4096) {
                errorBody = String(data: errorData, encoding: .utf8) ?? ""
            }
            if httpResponse.statusCode == 404, errorBody.localizedCaseInsensitiveContains("not found") {
                throw OllamaProviderError.modelUnavailable(modelName: activeModelName)
            }
            throw OllamaProviderError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        var fullResponseText = ""

        for try await line in byteStream.lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            guard let lineData = trimmedLine.data(using: .utf8) else {
                throw OllamaProviderError.malformedStreamChunk(trimmedLine)
            }

            let chunk: OllamaStreamChunk
            do {
                chunk = try JSONDecoder().decode(OllamaStreamChunk.self, from: lineData)
            } catch {
                throw OllamaProviderError.malformedStreamChunk(trimmedLine)
            }

            if let thinking = chunk.message?.thinking, !thinking.isEmpty {
                continue
            }
            if let content = chunk.message?.content, !content.isEmpty {
                let sanitizedChunk = OllamaResponseSanitizer.userFacingAssistantStreamDelta(
                    content: content,
                    separateThinkingField: nil
                )
                guard !sanitizedChunk.isEmpty else { continue }
                fullResponseText += sanitizedChunk
                await onTextChunk(sanitizedChunk)
            }

            if chunk.done == true {
                break
            }
        }

        let trimmedFullResponse = OllamaResponseSanitizer.userFacingAssistantText(
            content: fullResponseText,
            separateThinkingField: nil
        )
        guard !trimmedFullResponse.isEmpty else {
            throw OllamaProviderError.invalidResponse
        }

        return trimmedFullResponse
    }

    private func mapURLErrorToOllamaProviderError(_ urlError: URLError) -> OllamaProviderError {
        switch urlError.code {
        case .timedOut:
            return .notReachable
        case .cannotConnectToHost, .networkConnectionLost, .cannotFindHost, .notConnectedToInternet:
            return .notReachable
        default:
            return .notReachable
        }
    }

    private func evaluateConnectionStatus(forModelName modelNameToCheck: String? = nil) async -> AIProviderConnectionStatus {
        let modelNameToCheck = modelNameToCheck ?? modelName
        do {
            let installedModelNames = try await fetchInstalledModelNames()
            if Self.modelNameIsAvailable(modelNameToCheck, in: installedModelNames) {
                return .connected
            }
            return .modelUnavailable
        } catch {
            if error is OllamaProviderError {
                return .notConnected
            }
            if let urlError = error as? URLError {
                if urlError.code == .cannotConnectToHost
                    || urlError.code == .networkConnectionLost
                    || urlError.code == .cannotFindHost
                    || urlError.code == .timedOut {
                    return .notConnected
                }
            }
            return .notConnected
        }
    }

    private func fetchInstalledModelNames() async throws -> [String] {
        let tagsURL = endpointBaseURL.appendingPathComponent("api/tags")
        var urlRequest = URLRequest(url: tagsURL)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 5

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: urlRequest)
        } catch let urlError as URLError {
            throw OllamaProviderError.notReachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OllamaProviderError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return tagsResponse.models.map(\.name)
    }

    private func logVisionRequestDiagnostics(
        ollamaMessages: [OllamaChatRequest.Message],
        activeModelName: String,
        stream: Bool
    ) {
        let imageMessage = ollamaMessages.first { message in
            guard let images = message.images else { return false }
            return !images.isEmpty
        }
        let imageCount = imageMessage?.images?.count ?? 0
        let approximateImageBytes = imageMessage?.images?.first?.utf8.count ?? 0
        let roles = ollamaMessages.map(\.role).joined(separator: ", ")
        DexterDiagnosticLog.ollamaVision("model: \(activeModelName)")
        DexterDiagnosticLog.ollamaVision("endpoint: \(endpointBaseURL.absoluteString)/api/chat")
        DexterDiagnosticLog.ollamaVision("images: \(imageCount), approx base64 chars: \(approximateImageBytes)")
        DexterDiagnosticLog.ollamaVision("think: false, stream: \(stream)")
        DexterDiagnosticLog.ollamaVision("message roles: \(roles)")
        DexterDiagnosticLog.ollamaVision("system message present: \(ollamaMessages.contains { $0.role == "system" })")
    }

    static func modelNameIsAvailable(_ expectedModelName: String, in installedModelNames: [String]) -> Bool {
        let normalizedExpected = expectedModelName.lowercased()
        return installedModelNames.contains { installedName in
            let normalizedInstalled = installedName.lowercased()
            if normalizedInstalled == normalizedExpected {
                return true
            }
            if normalizedInstalled.hasPrefix(normalizedExpected + ":") {
                return true
            }
            if normalizedExpected.hasPrefix(normalizedInstalled + ":") {
                return true
            }
            return false
        }
    }
}

private extension URLSession.AsyncBytes {
    func collectData(upTo maxBytes: Int) async throws -> Data {
        var collectedData = Data()
        for try await byte in self {
            collectedData.append(byte)
            if collectedData.count >= maxBytes {
                break
            }
        }
        return collectedData
    }
}

//
//  ModelProvider.swift
//  leanring-buddy
//

import Foundation

struct DexterModelImageInput: Equatable {
    let imageData: Data
    let label: String
}

struct DexterModelGenerationRequest: Equatable {
    let systemPrompt: String
    let userPrompt: String
    let images: [DexterModelImageInput]
    let conversationHistory: [DexterConversationExchange]
    let userRequestedScreenContext: Bool
    let screenCaptureAvailability: DexterContextAvailability
    /// Scope-selected JPEG for local vision providers (1280 max edge, no upscale).
    let preparedVisionPayload: DexterPreparedVisionPayload?
    let visionRequest: DexterVisionRequest?

    init(
        systemPrompt: String,
        userPrompt: String,
        images: [DexterModelImageInput],
        conversationHistory: [DexterConversationExchange],
        userRequestedScreenContext: Bool = false,
        screenCaptureAvailability: DexterContextAvailability = .notApplicable,
        preparedVisionPayload: DexterPreparedVisionPayload? = nil,
        visionRequest: DexterVisionRequest? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.images = images
        self.conversationHistory = conversationHistory
        self.userRequestedScreenContext = userRequestedScreenContext
        self.screenCaptureAvailability = screenCaptureAvailability
        self.preparedVisionPayload = preparedVisionPayload
        self.visionRequest = visionRequest
    }
}

struct DexterModelGenerationResult: Equatable {
    let fullResponseText: String
    let duration: TimeInterval
    let visionResponse: DexterVisionResponse?

    init(
        fullResponseText: String,
        duration: TimeInterval,
        visionResponse: DexterVisionResponse? = nil
    ) {
        self.fullResponseText = fullResponseText
        self.duration = duration
        self.visionResponse = visionResponse
    }
}

/// Abstraction over reasoning/generation backends (Claude, OpenAI, etc.).
protocol ModelProvider: AnyObject {
    var modelIdentifier: String { get }
    func setModelIdentifier(_ modelIdentifier: String)
    func warmUpConnectionIfNeeded()
    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult
}

/// Routes generation through the existing Claude API client.
final class ClaudeModelProvider: ModelProvider {
    private let claudeAPI: ClaudeAPI

    var modelIdentifier: String {
        claudeAPI.model
    }

    init(claudeAPI: ClaudeAPI) {
        self.claudeAPI = claudeAPI
    }

    func setModelIdentifier(_ modelIdentifier: String) {
        claudeAPI.model = modelIdentifier
    }

    func warmUpConnectionIfNeeded() {
        _ = claudeAPI
    }

    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        let labeledImages = request.images.map { (data: $0.imageData, label: $0.label) }
        let historyForAPI = request.conversationHistory.map {
            (userPlaceholder: $0.userTranscript, assistantResponse: $0.assistantResponse)
        }

        let (fullText, duration) = try await claudeAPI.analyzeImageStreaming(
            images: labeledImages,
            systemPrompt: request.systemPrompt,
            conversationHistory: historyForAPI,
            userPrompt: request.userPrompt,
            onTextChunk: onTextChunk
        )

        return DexterModelGenerationResult(fullResponseText: fullText, duration: duration)
    }
}

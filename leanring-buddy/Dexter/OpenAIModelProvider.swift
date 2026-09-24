//
//  OpenAIModelProvider.swift
//  leanring-buddy
//

import Foundation

final class OpenAIModelProvider: ModelProvider {
    private let openAIAPI: OpenAIAPI

    static var isConfigured: Bool {
        guard let apiKey = AppBundleConfiguration.stringValue(forKey: "OpenAIAPIKey") else {
            return false
        }
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var modelIdentifier: String {
        openAIAPI.configuredModelName
    }

    init(openAIAPI: OpenAIAPI) {
        self.openAIAPI = openAIAPI
    }

    convenience init?() {
        guard let apiKey = AppBundleConfiguration.stringValue(forKey: "OpenAIAPIKey"),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        let modelName = AppBundleConfiguration.stringValue(forKey: "OpenAIChatModel") ?? "gpt-5.2-2025-12-11"
        self.init(openAIAPI: OpenAIAPI(apiKey: apiKey, model: modelName))
    }

    func setModelIdentifier(_ modelIdentifier: String) {
        openAIAPI.setModelName(modelIdentifier)
    }

    func warmUpConnectionIfNeeded() {
        openAIAPI.warmUpConnectionIfNeeded()
    }

    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        let labeledImages = request.images.map { (data: $0.imageData, label: $0.label) }
        let historyForAPI = request.conversationHistory.map {
            (userPlaceholder: $0.userTranscript, assistantResponse: $0.assistantResponse)
        }

        if labeledImages.isEmpty {
            let (fullText, duration) = try await openAIAPI.generateTextCompletion(
                systemPrompt: request.systemPrompt,
                conversationHistory: historyForAPI,
                userPrompt: request.userPrompt
            )
            await onTextChunk(fullText)
            return DexterModelGenerationResult(fullResponseText: fullText, duration: duration)
        }

        let (fullText, duration) = try await openAIAPI.analyzeImage(
            images: labeledImages,
            systemPrompt: request.systemPrompt,
            conversationHistory: historyForAPI,
            userPrompt: request.userPrompt
        )
        await onTextChunk(fullText)
        return DexterModelGenerationResult(fullResponseText: fullText, duration: duration)
    }
}

//
//  OllamaModelProviderAdapter.swift
//  leanring-buddy
//

import Foundation

/// Bridges Dexter orchestration (`ModelProvider`) to the local `AIProvider` (Ollama).
final class OllamaModelProviderAdapter: ModelProvider {
    private let aiProvider: OllamaProvider
    let visionProvider: VisionProvider

    var uiTargetVisionProvider: VisionProvider { visionProvider }

    var modelIdentifier: String {
        aiProvider.configuredModelName
    }

    init(
        aiProvider: OllamaProvider,
        visionProvider: VisionProvider? = nil
    ) {
        self.aiProvider = aiProvider
        self.visionProvider = visionProvider ?? FallbackVisionProvider(
            primaryProvider: OllamaVisionProvider(ollamaProvider: aiProvider),
            fallbackProvider: CloudVisionProvider()
        )
    }

    func setModelIdentifier(_ modelIdentifier: String) {
        aiProvider.setModelName(modelIdentifier)
    }

    func warmUpConnectionIfNeeded() {
        Task {
            await aiProvider.refreshConnectionStatus()
        }
    }

    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        let startDate = Date()

        if let visionRequest = request.visionRequest {
            DexterDiagnosticLog.vision(
                "VisionProvider analyze scope=\(visionRequest.scope.rawValue) provider=\(visionProvider.providerName)"
            )
            let visionResponse = try await visionProvider.analyze(
                request: visionRequest,
                onTextChunk: onTextChunk
            )
            let duration = Date().timeIntervalSince(startDate)
            return DexterModelGenerationResult(
                fullResponseText: visionResponse.conversationalAnswer,
                duration: duration,
                visionResponse: visionResponse
            )
        }

        let chatMessages = OllamaModelRequestTranslator.chatMessages(for: request)
        let visionImageBase64Payloads = OllamaModelRequestTranslator.encodeImagesForOllama(from: request.images)

        if !request.images.isEmpty && visionImageBase64Payloads.isEmpty {
            throw OllamaProviderError.imageEncodingFailed
        }

        if !visionImageBase64Payloads.isEmpty {
            DexterDiagnosticLog.vision("legacy multimodal Ollama path (\(visionImageBase64Payloads.count) image(s))")
            DexterTurnTrace.log("image encoded (\(visionImageBase64Payloads.first?.count ?? 0) base64 chars)")
        }

        let resolvedModelName = request.images.isEmpty
            ? OllamaModelConfiguration.textModelName
            : OllamaModelConfiguration.visionModelName

        DexterTurnTrace.log("OLLAMA REQUEST START model=\(resolvedModelName)")
        let fullResponseText = try await aiProvider.streamChat(
            messages: chatMessages,
            resolvedModelName: resolvedModelName,
            onTextChunk: onTextChunk
        )
        DexterTurnTrace.log("OLLAMA RESPONSE RECEIVED")
        DexterTurnTrace.log("MODEL RETURNED")

        let duration = Date().timeIntervalSince(startDate)
        return DexterModelGenerationResult(fullResponseText: fullResponseText, duration: duration)
    }
}

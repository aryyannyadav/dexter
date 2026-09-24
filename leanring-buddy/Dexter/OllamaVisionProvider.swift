//
//  OllamaVisionProvider.swift
//  leanring-buddy
//

import Foundation

/// Local vision through Ollama (`qwen3.5:4b`, think=false, stream=false).
final class OllamaVisionProvider: VisionProvider {
    let providerName = "Ollama"

    private let ollamaProvider: OllamaProvider

    init(ollamaProvider: OllamaProvider) {
        self.ollamaProvider = ollamaProvider
    }

    func isAvailable() async -> Bool {
        let status = await ollamaProvider.testConnection()
        switch status {
        case .connected:
            return true
        case .notConnected, .modelUnavailable, .unknown:
            return false
        }
    }

    func analyze(
        request: DexterVisionRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterVisionResponse {
        guard let encodedJPEG = DexterContextImageEncoder.jpegDataForVisionModel(
            from: request.jpegImageData,
            maxPixelDimension: DexterVisionImageEncoder.visionMaxPixelDimension,
            diagnosticReason: "ollama-vision-provider"
        ) ?? (request.jpegImageData.isEmpty ? nil : request.jpegImageData) else {
            throw VisionProviderError.imageEncodingFailed
        }

        var systemPrompt = DexterVisionSystemPrompt.screenAnalysisSystemPrompt
        if request.wantsStructuredObservations {
            systemPrompt += "\n\n" + DexterVisionSystemPrompt.structuredObservationsInstruction
        }

        var userContent = request.userQuestion
        if let pointerContextSummary = request.pointerContextSummary, !pointerContextSummary.isEmpty {
            userContent += "\n\nPointer context (metadata, may help focus): \(pointerContextSummary)"
        }
        userContent += "\n\nImage scope: \(request.scope.rawValue). Label: \(request.imageLabel)."

        let messages = [
            AIChatMessage(role: .system, content: systemPrompt),
            AIChatMessage(
                role: .user,
                content: userContent,
                base64Images: [encodedJPEG.base64EncodedString()]
            )
        ]

        DexterDiagnosticLog.vision("OllamaVisionProvider scope=\(request.scope.rawValue) think=false stream=false")
        DexterVisionTiming.markOllamaHTTPRequestSent()

        let rawText = try await ollamaProvider.streamChat(
            messages: messages,
            resolvedModelName: OllamaModelConfiguration.visionModelName,
            onTextChunk: onTextChunk
        )

        return DexterVisionObservationParser.parse(
            rawAssistantText: rawText,
            scopeUsed: request.scope,
            providerName: providerName
        )
    }
}

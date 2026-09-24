//
//  FallbackVisionProvider.swift
//  leanring-buddy
//

import Foundation

/// Tries a primary vision backend, then an optional fallback (never executes actions).
final class FallbackVisionProvider: VisionProvider {
    let providerName: String

    private let primaryProvider: VisionProvider
    private let fallbackProvider: VisionProvider?

    init(primaryProvider: VisionProvider, fallbackProvider: VisionProvider? = nil) {
        self.primaryProvider = primaryProvider
        self.fallbackProvider = fallbackProvider
        if let fallbackProvider {
            providerName = "\(primaryProvider.providerName)→\(fallbackProvider.providerName)"
        } else {
            providerName = primaryProvider.providerName
        }
    }

    func isAvailable() async -> Bool {
        if await primaryProvider.isAvailable() {
            return true
        }
        if let fallbackProvider {
            return await fallbackProvider.isAvailable()
        }
        return false
    }

    func analyze(
        request: DexterVisionRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterVisionResponse {
        if await primaryProvider.isAvailable() {
            return try await primaryProvider.analyze(request: request, onTextChunk: onTextChunk)
        }

        if let fallbackProvider, await fallbackProvider.isAvailable() {
            DexterDiagnosticLog.vision("vision fallback to \(fallbackProvider.providerName)")
            return try await fallbackProvider.analyze(request: request, onTextChunk: onTextChunk)
        }

        throw VisionProviderError.providerUnavailable(
            "No vision provider is available. Start Ollama and install \(OllamaModelConfiguration.visionModelName)."
        )
    }
}

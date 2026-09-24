//
//  CloudVisionProvider.swift
//  leanring-buddy
//

import Foundation

/// Placeholder for a future Cloudflare Worker / Claude vision path.
final class CloudVisionProvider: VisionProvider {
    let providerName = "Cloud"

    func isAvailable() async -> Bool {
        false
    }

    func analyze(
        request: DexterVisionRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterVisionResponse {
        _ = request
        _ = onTextChunk
        throw VisionProviderError.notImplemented(
            "Cloud vision is not enabled in this build. Use Ollama vision locally."
        )
    }
}

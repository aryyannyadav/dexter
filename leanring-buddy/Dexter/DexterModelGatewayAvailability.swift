//
//  DexterModelGatewayAvailability.swift
//  leanring-buddy
//

import Foundation

struct DexterModelGatewayAvailability: Equatable {
    var isOllamaReachable: Bool
    var isOllamaVisionModelAvailable: Bool
    var isOllamaTextModelAvailable: Bool
    var isClaudeWorkerConfigured: Bool
    var isOpenAIConfigured: Bool

    static let unavailable = DexterModelGatewayAvailability(
        isOllamaReachable: false,
        isOllamaVisionModelAvailable: false,
        isOllamaTextModelAvailable: false,
        isClaudeWorkerConfigured: false,
        isOpenAIConfigured: false
    )
}

@MainActor
enum DexterModelGatewayAvailabilityResolver {
    static func resolve(ollamaProvider: OllamaProvider) async -> DexterModelGatewayAvailability {
        await ollamaProvider.refreshConnectionStatus()
        let status = ollamaProvider.connectionStatus

        let isOllamaReachable = status == .connected || status == .modelUnavailable
        let isTextModelAvailable = status == .connected
        let isVisionModelAvailable = status == .connected

        return DexterModelGatewayAvailability(
            isOllamaReachable: isOllamaReachable,
            isOllamaVisionModelAvailable: isVisionModelAvailable,
            isOllamaTextModelAvailable: isTextModelAvailable,
            isClaudeWorkerConfigured: DexterWorkerProxyClient.isWorkerBaseURLConfigured,
            isOpenAIConfigured: OpenAIModelProvider.isConfigured
        )
    }
}

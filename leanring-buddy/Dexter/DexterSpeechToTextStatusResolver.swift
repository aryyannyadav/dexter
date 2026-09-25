//
//  DexterSpeechToTextStatusResolver.swift
//  leanring-buddy
//

import Foundation

struct DexterSpeechToTextReadiness: Equatable {
    let providerDisplayName: String
    let isReady: Bool
    let userStatusLine: String
    let developerDiagnosticLine: String
}

enum DexterSpeechToTextStatusResolver {
    static func resolve(provider: any BuddyTranscriptionProvider) -> DexterSpeechToTextReadiness {
        let preferredProviderRawValue = AppBundleConfiguration
            .stringValue(forKey: "VoiceTranscriptionProvider")?
            .lowercased() ?? "default"

        let workerConfigured = DexterWorkerProxyClient.isWorkerBaseURLConfigured
        let developerLine = [
            "VoiceTranscriptionProvider=\(preferredProviderRawValue)",
            "active=\(provider.displayName)",
            "workerProxyConfigured=\(workerConfigured)",
            "providerConfigured=\(provider.isConfigured)"
        ].joined(separator: ", ")

        if provider.isConfigured {
            return DexterSpeechToTextReadiness(
                providerDisplayName: provider.displayName,
                isReady: true,
                userStatusLine: "Ready",
                developerDiagnosticLine: developerLine
            )
        }

        let detail = provider.unavailableExplanation ?? "Speech recognition is not available."
        DexterDiagnosticLog.stt("STT not ready: \(developerLine) — \(detail)")

        return DexterSpeechToTextReadiness(
            providerDisplayName: provider.displayName,
            isReady: false,
            userStatusLine: "Not configured",
            developerDiagnosticLine: "\(developerLine); detail=\(detail)"
        )
    }
}

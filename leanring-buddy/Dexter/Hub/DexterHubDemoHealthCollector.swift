//
//  DexterHubDemoHealthCollector.swift
//  leanring-buddy
//
//  Developer-only demo health snapshot for Dexter Hub (honest statuses only).
//

import Foundation

struct DexterHubDemoHealthCheck: Equatable {
    let identifier: String
    let status: String
}

@MainActor
enum DexterHubDemoHealthCollector {
    static func collectSnapshot(
        isHubWebSocketServerRunning: Bool,
        hasPersistedScreenContentGrant: Bool,
        ollamaConnectionStatus: AIProviderConnectionStatus,
        isOllamaProviderEnabled: Bool,
        transcriptionProviderIsConfigured: Bool
    ) async -> [DexterHubDemoHealthCheck] {
        var checks: [DexterHubDemoHealthCheck] = []

        checks.append(
            DexterHubDemoHealthCheck(
                identifier: "DEXTER_APP",
                status: isHubWebSocketServerRunning ? "ok" : "fail"
            )
        )

        let permissionSnapshot = DexterPermissionManager().currentPermissionSnapshot(
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
        )

        let openClawMonitor = OpenClawGatewayHealthMonitor.shared
        await openClawMonitor.refreshHealthIfNeeded(force: false)
        let openClawReady = openClawMonitor.connectionState.isConnected
            && openClawMonitor.preferredNodeSnapshot.isConnected
        checks.append(
            DexterHubDemoHealthCheck(
                identifier: "OPENCLAW",
                status: openClawReady ? "ok" : "fail"
            )
        )

        checks.append(
            DexterHubDemoHealthCheck(
                identifier: "SCREEN",
                status: permissionSnapshot.hasScreenRecordingPermission ? "ok" : "fail"
            )
        )

        checks.append(
            DexterHubDemoHealthCheck(
                identifier: "MICROPHONE",
                status: permissionSnapshot.hasMicrophonePermission ? "ok" : "fail"
            )
        )

        checks.append(
            DexterHubDemoHealthCheck(
                identifier: "STT",
                status: transcriptionProviderIsConfigured ? "ok" : "fail"
            )
        )

        checks.append(
            DexterHubDemoHealthCheck(
                identifier: "TTS",
                status: "ok"
            )
        )

        if isOllamaProviderEnabled {
            let ollamaReady = ollamaConnectionStatus == .connected
            checks.append(
                DexterHubDemoHealthCheck(
                    identifier: "OLLAMA",
                    status: ollamaReady ? "ok" : "fail"
                )
            )
        }

        let verificationReady = permissionSnapshot.hasAccessibilityPermission
            && permissionSnapshot.hasScreenRecordingPermission
        checks.append(
            DexterHubDemoHealthCheck(
                identifier: "VERIFICATION",
                status: verificationReady ? "ok" : "fail"
            )
        )

        return checks
    }
}

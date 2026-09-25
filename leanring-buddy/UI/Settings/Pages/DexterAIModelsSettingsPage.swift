//
//  DexterAIModelsSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterAIModelsSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var ollamaProvider: OllamaProvider
    @StateObject private var ollamaSettings = DexterOllamaSettingsStore.shared
    @State private var visionModelInstalled = false
    @State private var isTestingConnection = false

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        self.ollamaProvider = companionManager.ollamaAIProvider
    }

    var body: some View {
        DexterSettingsPageContainer(
            title: "AI & Models",
            subtitle: "Configured models and local Ollama connectivity."
        ) {
            DexterSettingsSection(title: "Configured models") {
                DexterSettingsInfoRow(title: "Vision", value: ollamaProvider.configuredVisionModelName)
                DexterSettingsDivider()
                DexterSettingsInfoRow(title: "Text / reasoning", value: ollamaProvider.configuredModelName)
                DexterSettingsDivider()
                DexterSettingsInfoRow(title: "Vision status", value: visionStatusLabel)
                DexterSettingsDivider()
                DexterSettingsInfoRow(title: "Text status", value: textModelStatusLabel)
            }

            DexterSettingsSection(title: "Ollama") {
                DexterSettingsToggleRow(
                    title: "Use Ollama provider",
                    subtitle: "Route eligible requests to local Ollama when models are available.",
                    isOn: $ollamaSettings.isOllamaProviderEnabled
                )
                DexterSettingsDivider()
                DexterSettingsTextFieldRow(
                    title: "Endpoint",
                    placeholder: OllamaProvider.defaultEndpointString,
                    text: $ollamaSettings.endpointURLString,
                    onCommit: {
                        ollamaProvider.applyEndpointURLString(ollamaSettings.endpointURLString)
                        companionManager.refreshOllamaConnectionStatus()
                    }
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Connection",
                    value: ollamaProvider.connectionStatus.userFacingLabel
                )

                DexterSettingsSecondaryButton(title: isTestingConnection ? "Testing…" : "Test connection") {
                    runConnectionTest()
                }
                .disabled(isTestingConnection || !ollamaSettings.isOllamaProviderEnabled)
                .padding(.top, 6)

                if ollamaProvider.connectionStatus == .modelUnavailable {
                    Text("Install \(ollamaProvider.configuredModelName) with Ollama or run: ollama pull \(ollamaProvider.configuredModelName)")
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            DexterSettingsSection(title: "Routing") {
                Text("Dexter chooses models by capability (text, vision, reasoning, fast, local). There is no separate latency preset in this build.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            ollamaProvider.applyEndpointURLString(ollamaSettings.endpointURLString)
            companionManager.refreshOllamaConnectionStatus()
            refreshVisionModelInstalledFlag()
        }
    }

    private var visionStatusLabel: String {
        guard ollamaSettings.isOllamaProviderEnabled else { return "Disabled" }
        switch ollamaProvider.connectionStatus {
        case .connected:
            return visionModelInstalled ? "Connected" : "Not installed"
        case .unknown:
            return "Loading"
        case .notConnected:
            return "Unavailable"
        case .modelUnavailable:
            return "Not installed"
        }
    }

    private var textModelStatusLabel: String {
        guard ollamaSettings.isOllamaProviderEnabled else { return "Disabled" }
        switch ollamaProvider.connectionStatus {
        case .connected:
            return "Connected"
        case .unknown:
            return "Loading"
        case .notConnected:
            return "Unavailable"
        case .modelUnavailable:
            return "Not installed"
        }
    }

    private func runConnectionTest() {
        isTestingConnection = true
        ollamaProvider.applyEndpointURLString(ollamaSettings.endpointURLString)
        companionManager.testOllamaConnection()
        Task {
            let visionInstalled = await ollamaProvider.isVisionModelInstalled()
            await MainActor.run {
                visionModelInstalled = visionInstalled
                isTestingConnection = false
            }
        }
    }

    private func refreshVisionModelInstalledFlag() {
        Task {
            let visionInstalled = await ollamaProvider.isVisionModelInstalled()
            await MainActor.run {
                visionModelInstalled = visionInstalled
            }
        }
    }
}

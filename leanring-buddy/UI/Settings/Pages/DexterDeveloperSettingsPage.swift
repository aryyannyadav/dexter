//
//  DexterDeveloperSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterDeveloperSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var isDeveloperModeEnabled = DexterDeveloperModeSettings.isDeveloperModeEnabled
    @State private var showsResetConfirmation = false

    var body: some View {
        DexterSettingsPageContainer(
            title: "Developer",
            subtitle: "Diagnostics and technical runtime details."
        ) {
            DexterSettingsSection(title: "Developer mode") {
                DexterSettingsToggleRow(
                    title: "Developer mode",
                    subtitle: "Show gateway, node, and runtime diagnostics in Computer Control.",
                    isOn: Binding(
                        get: { isDeveloperModeEnabled },
                        set: { newValue in
                            isDeveloperModeEnabled = newValue
                            DexterDeveloperModeSettings.setDeveloperModeEnabled(newValue)
                        }
                    )
                )
            }

            if isDeveloperModeEnabled {
                DexterSettingsSection(title: "Runtime diagnostics") {
                    DexterSettingsInfoRow(
                        title: "Text model",
                        value: companionManager.ollamaAIProvider.configuredModelName
                    )
                    DexterSettingsDivider()
                    DexterSettingsInfoRow(
                        title: "Vision model",
                        value: companionManager.ollamaAIProvider.configuredVisionModelName
                    )
                    DexterSettingsDivider()
                    DexterSettingsInfoRow(
                        title: "Ollama connection",
                        value: companionManager.ollamaAIProvider.connectionStatus.userFacingLabel
                    )
                    DexterSettingsDivider()
                    DexterSettingsInfoRow(
                        title: "OpenClaw",
                        value: companionManager.openClawGatewayHealthMonitor.statusLine
                    )
                    DexterSettingsDivider()
                    DexterSettingsInfoRow(
                        title: "STT",
                        value: companionManager.buddyDictationManager.speechToTextReadiness.userStatusLine
                    )
                    DexterSettingsDivider()
                    DexterSettingsInfoRow(
                        title: "Spoken responses",
                        value: companionManager.isSpokenResponsesEnabled ? "On" : "Off"
                    )
                }

                #if DEBUG
                DexterSettingsSection(title: "Context inspector") {
                    DexterSettingsToggleRow(
                        title: "Context inspector",
                        subtitle: "Show last context snapshot in the menu bar panel (debug builds).",
                        isOn: Binding(
                            get: { DexterDevelopmentContextInspectorSettings.isEnabled },
                            set: { DexterDevelopmentContextInspectorSettings.setEnabled($0) }
                        )
                    )
                }
                #endif
            }

            DexterSettingsSection(title: "Reset") {
                DexterSettingsSecondaryButton(title: "Reset Dexter settings") {
                    showsResetConfirmation = true
                }
                Text("Resets appearance, cursor, voice toggles, screen context preferences, and developer mode. Does not delete conversations, saved memory, or Dexter profiles.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .confirmationDialog(
            "Reset Dexter settings?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset settings", role: .destructive) {
                DexterSettingsReset.resetDexterUIPreferences()
                isDeveloperModeEnabled = false
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

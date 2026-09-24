//
//  DexterSettingsView.swift
//  leanring-buddy
//

import AVFoundation
import SwiftUI

struct DexterSettingsView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var ollamaProvider: OllamaProvider

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        self.ollamaProvider = companionManager.ollamaAIProvider
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)

                settingsSection(title: "General") {
                    Toggle(isOn: Binding(
                        get: { companionManager.isDexterCursorEnabled },
                        set: { companionManager.setDexterCursorEnabled($0) }
                    )) {
                        settingsRowLabel("Show Dexter cursor overlay")
                    }
                    .toggleStyle(.switch)
                    .tint(DexterIdentity.accent)

                    Toggle(isOn: Binding(
                        get: { companionManager.autoApproveLowRiskActions },
                        set: { companionManager.autoApproveLowRiskActions = $0 }
                    )) {
                        settingsRowLabel("Auto-approve low-risk actions")
                    }
                    .toggleStyle(.switch)
                    .tint(DexterIdentity.accent)
                }

                settingsSection(title: "AI") {
                    ollamaSettingsBlock

                    Button("Test Connection") {
                        companionManager.testOllamaConnection()
                    }
                    .dsSecondaryButtonStyle()
                    .pointerCursor()
                }

                settingsSection(title: "Local actions") {
                    HStack {
                        settingsRowLabel("OpenClaw")
                        Spacer()
                        Text(companionManager.openClawGatewayStatusLine)
                            .font(DexterIdentity.Typography.monoCaption())
                            .foregroundColor(DS.Colors.textTertiary)
                            .multilineTextAlignment(.trailing)
                    }

                    Button("Check OpenClaw Gateway") {
                        companionManager.refreshOpenClawGatewayConnection()
                    }
                    .dsSecondaryButtonStyle()
                    .pointerCursor()

                    Text("Computer actions (for example opening Calculator) run through your local OpenClaw Gateway after Dexter permission checks. Chat and vision still use Ollama when OpenClaw is offline.")
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                settingsSection(title: "Voice") {
                    Toggle(isOn: Binding(
                        get: { companionManager.isPushToTalkEnabled },
                        set: { companionManager.isPushToTalkEnabled = $0 }
                    )) {
                        settingsRowLabel("Push-to-talk")
                    }
                    .toggleStyle(.switch)
                    .tint(DexterIdentity.accent)

                    Toggle(isOn: Binding(
                        get: { companionManager.isSpokenResponsesEnabled },
                        set: { companionManager.isSpokenResponsesEnabled = $0 }
                    )) {
                        settingsRowLabel("Spoken responses")
                    }
                    .toggleStyle(.switch)
                    .tint(DexterIdentity.accent)

                    HStack {
                        settingsRowLabel("Speech-to-text")
                        Spacer()
                        Text(companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                            .font(DexterIdentity.Typography.monoCaption())
                            .foregroundColor(DS.Colors.textTertiary)
                    }

                    Picker("Mac voice", selection: Binding(
                        get: { companionManager.preferredMacSpeechVoiceIdentifier ?? "" },
                        set: { newValue in
                            companionManager.preferredMacSpeechVoiceIdentifier = newValue.isEmpty ? nil : newValue
                        }
                    )) {
                        Text("Automatic (best available)").tag("")
                        ForEach(DexterMacSpeechVoiceSelector.availableEnglishVoices(), id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                    .pickerStyle(.menu)
                }

                settingsSection(title: "Context & Privacy") {
                    DexterPermissionList(companionManager: companionManager)
                    DexterMemoryManagementView(companionManager: companionManager)
                        .onAppear { companionManager.reloadDexterMemoryPresentation() }
                }

                settingsSection(title: "Shortcuts") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hold Control + Option to talk to Dexter from anywhere.")
                            .font(DexterIdentity.Typography.body())
                            .foregroundColor(DS.Colors.textSecondary)
                        Text("Press \(DexterPointInvokeShortcut.displayText) to capture what you're pointing at and open Dexter.")
                            .font(DexterIdentity.Typography.body())
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                settingsSection(title: "About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DexterProductCopy.name)
                            .font(DexterIdentity.Typography.title())
                            .foregroundColor(DS.Colors.textPrimary)
                        Text(DexterProductCopy.tagline)
                            .font(DexterIdentity.Typography.body())
                            .foregroundColor(DS.Colors.textSecondary)
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                            .font(DexterIdentity.Typography.monoCaption())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(DS.Colors.background)
    }

    private var ollamaSettingsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsKeyValueRow(label: "Provider", value: ollamaProvider.providerName)
            settingsKeyValueRow(label: "Endpoint", value: ollamaProvider.endpointDisplayString)
            settingsKeyValueRow(label: "Model", value: ollamaProvider.configuredModelName)
            settingsKeyValueRow(label: "Connection status", value: ollamaProvider.connectionStatus.userFacingLabel)

            if ollamaProvider.connectionStatus == .modelUnavailable {
                Text("Install \(ollamaProvider.configuredModelName) with the Ollama app or run: ollama pull \(ollamaProvider.configuredModelName)")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: DS.CornerRadius.medium).fill(DS.Colors.surface2))
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.medium)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .onAppear {
            companionManager.refreshOllamaConnectionStatus()
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(DexterIdentity.Typography.sectionLabel())
                .foregroundColor(DS.Colors.textTertiary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.large, style: .continuous)
                    .fill(DS.Colors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.large, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func settingsRowLabel(_ text: String) -> some View {
        Text(text)
            .font(DexterIdentity.Typography.body())
            .foregroundColor(DS.Colors.textSecondary)
    }

    private func settingsKeyValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DexterIdentity.Typography.monoCaption())
                .foregroundColor(DS.Colors.textTertiary)
        }
    }
}

//
//  DexterVoiceSettingsPage.swift
//  leanring-buddy
//

import AVFoundation
import SwiftUI

struct DexterVoiceSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @StateObject private var microphoneSettings = DexterMicrophoneSettingsStore.shared
    @StateObject private var dictationSettings = DexterDictationSettingsStore.shared
    @StateObject private var shortcutSettings = DexterShortcutSettingsStore.shared
    @State private var isPreviewingVoice = false
    @State private var previewErrorMessage: String?
    @State private var availableInputDevices: [DexterMicrophoneInputDevice] = []

    private let voicePreviewPhrase = "Hi, I'm Dexter."

    var body: some View {
        DexterSettingsPageContainer(
            title: "Voice",
            subtitle: "Push-to-talk input and spoken responses."
        ) {
            DexterSettingsSection(title: "Voice input") {
                DexterSettingsInfoRow(
                    title: "Microphone",
                    value: microphonePermissionLabel
                )
                if !companionManager.hasMicrophonePermission {
                    DexterSettingsSecondaryButton(title: "Open System Settings") {
                        companionManager.buddyDictationManager.openRelevantPrivacySettings()
                    }
                    .padding(.top, 4)
                }
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "Push to talk",
                    subtitle: "Hold the shortcut to speak; release to send.",
                    isOn: Binding(
                        get: { companionManager.isPushToTalkEnabled },
                        set: { companionManager.isPushToTalkEnabled = $0 }
                    )
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Shortcut",
                    value: shortcutSettings.pushToTalkShortcutOption.displayText
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Voice input status",
                    value: companionManager.buddyDictationManager.speechToTextReadiness.userStatusLine
                )

                if !availableInputDevices.isEmpty {
                    DexterSettingsDivider()
                    Picker("Microphone device", selection: Binding(
                        get: { microphoneSettings.preferredInputDeviceIdentifier ?? "" },
                        set: { newValue in
                            microphoneSettings.preferredInputDeviceIdentifier = newValue.isEmpty ? nil : newValue
                            companionManager.buddyDictationManager.preferredMicrophoneDeviceIdentifier =
                                microphoneSettings.preferredInputDeviceIdentifier
                        }
                    )) {
                        Text("System default").tag("")
                        ForEach(availableInputDevices) { device in
                            Text(device.displayName).tag(device.id)
                        }
                    }
                    .labelsHidden()
                }
            }

            DexterSettingsSection(title: "Dictation language") {
                DexterSettingsToggleRow(
                    title: "Auto-detect language",
                    subtitle: "Let Dexter infer the spoken language when supported.",
                    isOn: $dictationSettings.isAutoDetectLanguageEnabled
                )
            }

            DexterSettingsSection(title: "Voice output") {
                DexterSettingsToggleRow(
                    title: "Spoken responses",
                    subtitle: "Read answers aloud after Dexter finishes thinking.",
                    isOn: Binding(
                        get: { companionManager.isSpokenResponsesEnabled },
                        set: { companionManager.isSpokenResponsesEnabled = $0 }
                    )
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Voice",
                    value: DexterWorkerProxyClient.isWorkerBaseURLConfigured ? "Cloud voice available" : "Mac voice"
                )

                Picker("Mac voice fallback", selection: Binding(
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
                .labelsHidden()
                .padding(.top, 6)

                DexterSettingsSecondaryButton(title: isPreviewingVoice ? "Previewing…" : "Preview voice") {
                    previewVoice()
                }
                .disabled(isPreviewingVoice)
                .padding(.top, 8)

                if let previewErrorMessage {
                    Text(previewErrorMessage)
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
        }
        .onAppear {
            availableInputDevices = DexterMicrophoneDeviceCatalog.availableInputDevices()
            companionManager.buddyDictationManager.preferredMicrophoneDeviceIdentifier =
                microphoneSettings.preferredInputDeviceIdentifier
        }
    }

    private var microphonePermissionLabel: String {
        companionManager.hasMicrophonePermission ? "Allowed" : "Permission required"
    }

    private func previewVoice() {
        previewErrorMessage = nil
        isPreviewingVoice = true
        previewMacVoiceFallback()
    }

    private func previewMacVoiceFallback() {
        let utterance = AVSpeechUtterance(string: voicePreviewPhrase)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.voice = DexterMacSpeechVoiceSelector.resolveVoice(
            preferredVoiceIdentifier: companionManager.preferredMacSpeechVoiceIdentifier
        )
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isPreviewingVoice = false
        }
    }
}

//
//  DexterMicrophoneSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterMicrophoneSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @StateObject private var microphoneSettings = DexterMicrophoneSettingsStore.shared
    @State private var availableInputDevices: [DexterMicrophoneInputDevice] = []

    var body: some View {
        DexterSettingsPageContainer(
            title: "Microphone",
            subtitle: "Input device and permission state for push-to-talk."
        ) {
            DexterSettingsSection(title: "Permission") {
                DexterSettingsInfoRow(
                    title: "Microphone access",
                    value: microphonePermissionLabel
                )
                if !companionManager.hasMicrophonePermission {
                    DexterSettingsSecondaryButton(title: "Open System Settings") {
                        companionManager.buddyDictationManager.openRelevantPrivacySettings()
                    }
                    .padding(.top, 4)
                }
            }

            DexterSettingsSection(title: "Speech-to-text") {
                let readiness = companionManager.buddyDictationManager.speechToTextReadiness
                DexterSettingsInfoRow(
                    title: "Provider",
                    value: readiness.providerDisplayName
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Status",
                    value: readiness.isReady ? readiness.userStatusLine : readiness.userStatusLine
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Runtime state",
                    value: companionManager.microphoneRuntimeStateLabel
                )
                if !readiness.isReady {
                    Text("Cloud transcription uses your configured worker proxy when available. Without it, Dexter uses Apple Speech on this Mac.")
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }

            if !availableInputDevices.isEmpty {
                DexterSettingsSection(title: "Input device") {
                    Picker("Microphone", selection: Binding(
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Applies the next time Dexter starts a push-to-talk capture session.")
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }

            DexterSettingsSection(title: "Push-to-talk") {
                DexterSettingsToggleRow(
                    title: "Enable push-to-talk",
                    subtitle: nil,
                    isOn: Binding(
                        get: { companionManager.isPushToTalkEnabled },
                        set: { companionManager.isPushToTalkEnabled = $0 }
                    )
                )
            }
        }
        .onAppear {
            availableInputDevices = DexterMicrophoneDeviceCatalog.availableInputDevices()
            companionManager.buddyDictationManager.preferredMicrophoneDeviceIdentifier =
                microphoneSettings.preferredInputDeviceIdentifier
        }
    }

    private var microphonePermissionLabel: String {
        switch companionManager.microphonePermissionState {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not determined"
        case .requesting:
            return "Requesting…"
        case .unavailable:
            return "Unavailable"
        }
    }
}

private extension CompanionManager {
    var microphoneRuntimeStateLabel: String {
        switch microphoneRuntimeState {
        case .idle: return "Idle"
        case .starting: return "Starting"
        case .listening: return "Listening"
        case .processing: return "Processing"
        case .error: return "Error"
        }
    }
}

//
//  DexterCompanionPanelContent.swift
//  leanring-buddy
//

import AVFoundation
import AppKit
import SwiftUI

/// Polished Dexter menu bar panel — composes voice, chat, actions, task, memory, and settings.
struct DexterCompanionPanelContent: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var emailInput: String = ""
    @State private var isAdvancedSettingsExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider().background(DS.Colors.borderSubtle).padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    onboardingOrPermissionsBlock
                        .padding(.top, 12)

                    if companionManager.interactiveOnboardingStore.isActive {
                        DexterInteractiveOnboardingCard(
                            interactiveOnboardingStore: companionManager.interactiveOnboardingStore
                        )
                        permissionsReminderIfNeeded
                    } else if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                        DexterRuntimeUIStateBanner(runtimeUIStateStore: companionManager.dexterRuntimeUIStateStore)
                        voiceAndChatSection
                        actionAndExecutionSection
                        taskStatusSection
                        settingsSection
                        if isAdvancedSettingsExpanded {
                            DexterMemoryManagementView(companionManager: companionManager)
                                .onAppear { companionManager.reloadDexterMemoryPresentation() }
                        }
                    } else if !companionManager.allPermissionsGranted {
                        permissionsListSection
                    }

                    if !companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                        startOnboardingBlock
                    }

                    #if DEBUG
                    if companionManager.hasCompletedOnboarding {
                        CompanionDevelopmentContextInspectorView(companionManager: companionManager)
                    }
                    #endif
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 520)

            Divider().background(DS.Colors.borderSubtle).padding(.horizontal, 16)
            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: DexterIdentity.panelWidth)
        .background(
            RoundedRectangle(cornerRadius: DexterIdentity.panelCornerRadius, style: .continuous)
                .fill(DS.Colors.background)
                .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
        )
    }

    private var header: some View {
        return DexterFloatingCompanionHeader(
            statusChipLabel: panelStatusText,
            isStatusActive: companionManager.voiceInteractionState != .idle || companionManager.isOverlayVisible,
            onDismiss: {
                NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)
            }
        )
    }

    @ViewBuilder
    private var onboardingOrPermissionsBlock: some View {
        if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
            EmptyView()
        } else if companionManager.allPermissionsGranted && !companionManager.hasSubmittedEmail {
            emailCaptureBlock
        } else {
            Text(onboardingCopy)
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var voiceAndChatSection: some View {
        VStack(spacing: 12) {
            DexterVoiceStatusCard(
                activationLabel: DexterPanelPresentation.voiceActivationLabel(
                    interactionState: companionManager.voiceInteractionState,
                    isPushToTalkEnabled: companionManager.isPushToTalkEnabled,
                    hasCompletedSetup: true
                ),
                interactionState: companionManager.voiceInteractionState,
                audioPowerLevel: companionManager.currentAudioPowerLevel,
                isPushToTalkEnabled: companionManager.isPushToTalkEnabled
            )

            DexterChatCard(
                userMessage: companionManager.lastTranscript,
                assistantStreamingText: companionManager.dexterVoiceCoordinator.streamingResponseText,
                assistantFinalText: companionManager.dexterVoiceCoordinator.lastAssistantResponseText
            )

            DexterPanelCard {
                VStack(alignment: .leading, spacing: 8) {
                    DexterSectionHeader(title: "Compose", subtitle: "Text works with or without voice")
                    DexterVoiceTextInputView(companionManager: companionManager)
                }
            }
        }
    }

    @ViewBuilder
    private var actionAndExecutionSection: some View {
        if let failurePresentation = companionManager.dexterRuntimeUIStateStore.failurePresentation {
            DexterRuntimeFailureCard(failurePresentation: failurePresentation)
        }

        if let confirmation = companionManager.actionConfirmationPresentation {
            DexterActionConfirmationView(
                presentation: confirmation,
                onCancel: { companionManager.cancelPendingActionConfirmation() },
                onAllow: { companionManager.approvePendingActionConfirmation() }
            )
        } else if let action = companionManager.panelLastTypedAction {
            let runtimeState = companionManager.dexterRuntimeUIStateStore.currentState
            switch runtimeState {
            case .planning, .waitingPermission:
                if let phase = DexterPanelPresentation.actionPhaseLabel(for: action) {
                    DexterActionProposalCard(actionDescription: action.humanReadableDescription, phaseLabel: phase)
                }
            case .acting, .verifying:
                DexterExecutionProgressCard(
                    runtimeState: runtimeState,
                    statusDetail: companionManager.dexterRuntimeUIStateStore.statusDetail,
                    actionDescription: action.humanReadableDescription
                )
            case .done:
                let verificationLabel = DexterPanelPresentation.verificationResultLabel(for: action)
                if verificationLabel != .none {
                    DexterVerificationResultCard(
                        resultLabel: verificationLabel,
                        summary: companionManager.panelLastActionSummary
                    )
                }
            case .failed, .cancelled:
                EmptyView()
            default:
                if let phase = DexterPanelPresentation.actionPhaseLabel(for: action) {
                    switch action.state {
                    case .proposed, .awaitingConfirmation:
                        DexterActionProposalCard(actionDescription: action.humanReadableDescription, phaseLabel: phase)
                    case .completed, .failed, .verificationFailed:
                        let verificationLabel = DexterPanelPresentation.verificationResultLabel(for: action)
                        if verificationLabel != .none {
                            DexterVerificationResultCard(
                                resultLabel: verificationLabel,
                                summary: companionManager.panelLastActionSummary
                            )
                        }
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var taskStatusSection: some View {
        if let headline = DexterPanelPresentation.taskStatusHeadline(for: companionManager.panelActiveWorkflowTask),
           let detail = DexterPanelPresentation.taskStatusDetail(for: companionManager.panelActiveWorkflowTask) {
            DexterTaskStatusCard(headline: headline, detail: detail)
        }
    }

    @ViewBuilder
    private var permissionsReminderIfNeeded: some View {
        if !companionManager.allPermissionsGranted {
            permissionsListSection
        }
    }

    private var settingsSection: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 12) {
                DexterSectionHeader(title: "Settings")

                Toggle(isOn: Binding(
                    get: { companionManager.isPushToTalkEnabled },
                    set: { companionManager.isPushToTalkEnabled = $0 }
                )) {
                    Text("Push-to-talk")
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(DexterIdentity.accent)

                Toggle(isOn: Binding(
                    get: { companionManager.isSpokenResponsesEnabled },
                    set: { companionManager.isSpokenResponsesEnabled = $0 }
                )) {
                    Text("Spoken responses")
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(DexterIdentity.accent)

                Toggle(isOn: Binding(
                    get: { companionManager.autoApproveLowRiskActions },
                    set: { companionManager.autoApproveLowRiskActions = $0 }
                )) {
                    Text("Auto-approve low-risk actions")
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.switch)
                .tint(DexterIdentity.accent)

                DisclosureGroup(isExpanded: $isAdvancedSettingsExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        modelPickerRow
                        speechToTextProviderRow
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Advanced")
                        .font(DexterIdentity.Typography.bodyMedium())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Reused panel pieces (permissions, onboarding, footer)

    private var onboardingCopy: String {
        if companionManager.hasCompletedOnboarding {
            return "Grant all permissions below to restore Dexter."
        }
        return "Grant permissions, then try Dexter on your screen — point, ask, and act."
    }

    private var panelStatusText: String {
        if !companionManager.hasCompletedOnboarding || !companionManager.allPermissionsGranted {
            return "Setup"
        }
        let runtimeState = companionManager.dexterRuntimeUIStateStore.currentState
        if runtimeState != .idle {
            return runtimeState.rawValue
        }
        if !companionManager.isOverlayVisible {
            return "Ready"
        }
        return DexterPanelPresentation.voiceActivationLabel(
            interactionState: companionManager.voiceInteractionState,
            isPushToTalkEnabled: companionManager.isPushToTalkEnabled,
            hasCompletedSetup: true
        ).rawValue
    }

    private var emailCaptureBlock: some View {
        VStack(spacing: 8) {
            TextField("Email for updates", text: $emailInput)
                .textFieldStyle(.plain)
                .font(DexterIdentity.Typography.body())
                .padding(10)
                .background(RoundedRectangle(cornerRadius: DS.CornerRadius.medium).fill(DS.Colors.surface2))
            Button("Continue") { companionManager.submitEmail(emailInput) }
                .dsPrimaryButtonStyle()
                .disabled(emailInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var startOnboardingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You'll point at something, ask what it is, then ask Dexter to do a small safe action.")
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Start") { companionManager.triggerOnboarding() }
                .dsPrimaryButtonStyle()
        }
    }

    private var permissionsListSection: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 4) {
                DexterSectionHeader(title: "Permissions")
                Text("Required for voice, screen context, and actions.")
                    .font(DexterIdentity.Typography.body())
                    .foregroundColor(DS.Colors.textTertiary)
                CompanionPanelPermissionsList(companionManager: companionManager)
            }
        }
    }

    private var modelPickerRow: some View {
        HStack {
            Text("Model")
                .font(DexterIdentity.Typography.bodyMedium())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            HStack(spacing: 0) {
                modelButton("Sonnet", id: "claude-sonnet-4-6")
                modelButton("Opus", id: "claude-opus-4-6")
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(DS.Colors.surface3))
        }
    }

    private func modelButton(_ label: String, id: String) -> some View {
        let selected = companionManager.selectedModel == id
        return Button(label) { companionManager.setSelectedModel(id) }
            .font(DexterIdentity.Typography.monoCaption())
            .foregroundColor(selected ? DexterIdentity.accent : DS.Colors.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? DexterIdentity.accentSubtle : Color.clear)
            .buttonStyle(.plain)
            .pointerCursor()
    }

    private var speechToTextProviderRow: some View {
        HStack {
            Text("Speech-to-text")
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            Text(companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                .font(DexterIdentity.Typography.monoCaption())
                .foregroundColor(DS.Colors.textTertiary)
        }
    }

    private var footer: some View {
        HStack {
            Button("Quit") { NSApp.terminate(nil) }
                .dsTextButtonStyle(fontSize: 12)
            Spacer()
            if companionManager.hasCompletedOnboarding {
                Button("Replay onboarding") { companionManager.replayOnboarding() }
                    .dsTextButtonStyle(fontSize: 12)
            }
        }
        .foregroundColor(DS.Colors.textTertiary)
    }
}

/// Extracted permission rows from the legacy panel for reuse.
struct CompanionPanelPermissionsList: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        VStack(spacing: 0) {
            microphonePermissionRow
            openSettingsPermissionRow(
                title: "Accessibility",
                granted: companionManager.hasAccessibilityPermission,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
            openSettingsPermissionRow(
                title: "Screen Recording",
                granted: companionManager.hasScreenRecordingPermission,
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            )
            if companionManager.hasScreenRecordingPermission {
                screenContentPermissionRow
            }
        }
    }

    private var microphonePermissionRow: some View {
        HStack {
            Text("Microphone")
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            if companionManager.hasMicrophonePermission {
                Text("OK")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.success)
            } else {
                Button("Grant") {
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    if status == .notDetermined {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in }
                    } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(DexterIdentity.Typography.monoCaption())
                .foregroundColor(DexterIdentity.accent)
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }

    private var screenContentPermissionRow: some View {
        HStack {
            Text("Screen Content")
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            if companionManager.hasScreenContentPermission {
                Text("OK")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.success)
            } else {
                Button("Grant") { companionManager.requestScreenContentPermission() }
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DexterIdentity.accent)
                    .buttonStyle(.plain)
                    .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }

    private func openSettingsPermissionRow(title: String, granted: Bool, settingsURL: String) -> some View {
        HStack {
            Text(title)
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            if granted {
                Text("OK")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.success)
            } else if let url = URL(string: settingsURL) {
                Button("Grant") { NSWorkspace.shared.open(url) }
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DexterIdentity.accent)
                    .buttonStyle(.plain)
                    .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }
}

//
//  DexterMenuBarPanelContent.swift
//  leanring-buddy
//

import AVFoundation
import AppKit
import SwiftUI

/// Compact menu bar popover — quick access without replacing the main Dexter window.
struct DexterMenuBarPanelContent: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var quickMessageText: String = ""

    private let panelWidth: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider().background(DS.Colors.borderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !companionManager.allPermissionsGranted {
                        permissionsBlock
                    } else if companionManager.interactiveOnboardingStore.isActive {
                        DexterInteractiveOnboardingCard(
                            interactiveOnboardingStore: companionManager.interactiveOnboardingStore
                        )
                    } else if companionManager.hasCompletedOnboarding {
                        DexterRuntimeUIStateBanner(runtimeUIStateStore: companionManager.dexterRuntimeUIStateStore)
                        contextRow
                        voiceRow
                        quickCompose
                        compactActionSection
                    } else {
                        onboardingBlock
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 420)

            Divider().background(DS.Colors.borderSubtle)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: panelWidth)
        .background(
            RoundedRectangle(cornerRadius: DexterIdentity.panelCornerRadius, style: .continuous)
                .fill(DS.Colors.background)
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            DexterMark(size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(DexterProductCopy.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                Text(DexterProductCopy.tagline)
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.textTertiary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(6)
                    .background(Circle().fill(DS.Colors.surface2))
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityLabel("Close panel")
        }
    }

    private var contextRow: some View {
        DexterContextIndicator(
            uiState: companionManager.dexterScreenContextUIState,
            compact: true
        )
    }

    private var voiceRow: some View {
        HStack(spacing: 14) {
            DexterVoiceButton(
                interactionState: companionManager.microphoneButtonInteractionState,
                audioPowerLevel: companionManager.currentAudioPowerLevel,
                isPushToTalkEnabled: companionManager.isPushToTalkEnabled,
                hasError: companionManager.microphoneButtonShowsError,
                size: .compact,
                onPress: { companionManager.beginPushToTalkFromVoiceControl() },
                onRelease: { companionManager.endPushToTalkFromVoiceControl() }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(DexterPanelPresentation.voiceActivationLabel(
                    interactionState: companionManager.voiceInteractionState,
                    isPushToTalkEnabled: companionManager.isPushToTalkEnabled,
                    hasCompletedSetup: companionManager.allPermissionsGranted
                ).rawValue)
                    .font(DexterIdentity.Typography.bodyMedium())
                    .foregroundColor(DS.Colors.textPrimary)
                Text("Hold to talk, or use Control + Option")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(DS.Colors.surface1))
    }

    private var quickCompose: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick message")
                .font(DexterIdentity.Typography.sectionLabel())
                .foregroundColor(DS.Colors.textTertiary)

            HStack(spacing: 8) {
                TextField("Ask Dexter…", text: $quickMessageText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(DS.Colors.surface2))
                    .onSubmit(sendQuickMessage)

                Button(action: sendQuickMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DexterIdentity.accent)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .disabled(quickMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var compactActionSection: some View {
        if let confirmation = companionManager.actionConfirmationPresentation {
            DexterActionConfirmationView(
                presentation: confirmation,
                onCancel: { companionManager.cancelPendingActionConfirmation() },
                onAllow: { companionManager.approvePendingActionConfirmation() }
            )
        }
    }

    private var permissionsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions required")
                .font(DexterIdentity.Typography.bodyMedium())
                .foregroundColor(DS.Colors.textPrimary)
            DexterPermissionList(companionManager: companionManager)
        }
    }

    private var onboardingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dexter lives in your menu bar — voice, screen context, and guided help when you ask.")
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
            Button("Get started") { companionManager.triggerOnboarding() }
                .dsPrimaryButtonStyle()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Open Dexter") {
                NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
                NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)
            }
            .dsTextButtonStyle(fontSize: 12)

            Button("Settings") {
                NotificationCenter.default.post(name: .dexterOpenMainWindowSettings, object: nil)
                NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)
            }
            .dsTextButtonStyle(fontSize: 12)

            Spacer()

            Button("Quit") { NSApp.terminate(nil) }
                .dsTextButtonStyle(fontSize: 12)
        }
        .foregroundColor(DS.Colors.textTertiary)
    }

    private func sendQuickMessage() {
        let trimmed = quickMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        quickMessageText = ""
        companionManager.submitTextMessageToDexter(trimmed)
    }
}

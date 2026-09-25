//
//  DexterHomeComposer.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeComposer: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var messageText: String
    var activeProfile: DexterProfile?

    @FocusState private var isComposerFocused: Bool
    @State private var isSending = false
    @ObservedObject private var shortcutSettings = DexterShortcutSettingsStore.shared

    var body: some View {
        VStack(spacing: DexterSpacing.xs) {
            HStack(alignment: .bottom, spacing: DexterSpacing.sm) {
                voiceControl

                HStack(alignment: .bottom, spacing: DexterSpacing.sm) {
                    TextField("Type a message…", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(DexterSurfaceColors.textPrimary)
                        .lineLimit(1...5)
                        .focused($isComposerFocused)
                        .onSubmit { submitMessage() }

                    Button(action: submitMessage) {
                        Image(systemName: isSending ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(
                                canSend
                                    ? (activeProfile?.accentColor ?? DexterPastelColors.lavender)
                                    : DexterSurfaceColors.textMuted
                            )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(.horizontal, DexterSpacing.md)
                .padding(.vertical, DexterSpacing.sm + 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DexterRadii.large, style: .continuous)
                        .fill(DexterSurfaceColors.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DexterRadii.large, style: .continuous)
                        .stroke(composerBorderColor, lineWidth: isComposerFocused ? 1.5 : 1)
                )
            }
            .frame(maxWidth: 640)

            if !releaseHelperText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(releaseHelperText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(DexterSurfaceColors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DexterConversationLayout.messageColumnHorizontalPadding)
        .padding(.vertical, DexterConversationLayout.composerBottomInset)
        .background(
            LinearGradient(
                colors: [
                    DexterSurfaceColors.background.opacity(0),
                    DexterSurfaceColors.background.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onChange(of: companionManager.shouldFocusHomeComposerAfterOnboarding) { _, shouldFocus in
            guard shouldFocus else { return }
            isComposerFocused = true
            companionManager.shouldFocusHomeComposerAfterOnboarding = false
        }
        .onAppear {
            if companionManager.shouldFocusHomeComposerAfterOnboarding {
                isComposerFocused = true
                companionManager.shouldFocusHomeComposerAfterOnboarding = false
            }
        }
    }

    @ViewBuilder
    private var voiceControl: some View {
        if companionManager.isPushToTalkEnabled {
            DexterConversationVoicePill(
                interactionState: companionManager.microphoneButtonInteractionState,
                audioPowerLevel: companionManager.currentAudioPowerLevel,
                isPushToTalkEnabled: companionManager.isPushToTalkEnabled,
                hasError: companionManager.microphoneButtonShowsError,
                shortcutLabel: shortcutSettings.pushToTalkShortcutOption.displayText,
                onPress: { companionManager.beginPushToTalkFromVoiceControl() },
                onRelease: { companionManager.endPushToTalkFromVoiceControl() }
            )
            .frame(width: 148)
        } else {
            Button {
                companionManager.beginPushToTalkFromVoiceControl()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DexterPastelColors.lavender)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(DexterSurfaceColors.surfaceElevated)
                    )
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityLabel("Voice input")
        }
    }

    private var releaseHelperText: String {
        switch companionManager.voiceInteractionState {
        case .listening, .transcribing:
            return "Release \(shortcutSettings.pushToTalkShortcutOption.displayText) to send"
        case .thinking:
            return "Dexter is thinking…"
        case .speaking:
            return "Dexter is speaking…"
        default:
            return ""
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private var composerBorderColor: Color {
        if isComposerFocused {
            return activeProfile?.accentColor.opacity(0.45) ?? DexterPastelColors.lavender.opacity(0.45)
        }
        return DexterSurfaceColors.border.opacity(0.65)
    }

    private func submitMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        messageText = ""
        companionManager.submitTextMessageToDexter(trimmed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isSending = false
        }
    }
}

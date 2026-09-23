//
//  DexterComposer.swift
//  leanring-buddy
//

import SwiftUI

struct DexterComposer: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var messageText: String
    var showsVoiceButton: Bool = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if showsVoiceButton {
                DexterVoiceButton(
                    interactionState: companionManager.voiceInteractionState,
                    audioPowerLevel: companionManager.currentAudioPowerLevel,
                    isPushToTalkEnabled: companionManager.isPushToTalkEnabled,
                    hasError: companionManager.dexterChatErrorMessage != nil,
                    onPress: { companionManager.beginPushToTalkFromVoiceControl() },
                    onRelease: { companionManager.endPushToTalkFromVoiceControl() }
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                DexterContextIndicator(
                    isScreenContextAvailable: companionManager.isDexterScreenContextAvailable,
                    compact: true
                )

                HStack(spacing: 8) {
                    TextField("Message Dexter…", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1...6)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                                .fill(DS.Colors.surface2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                        .onSubmit { submitMessage() }

                    Button(action: submitMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(
                                messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? DS.Colors.textTertiary
                                    : DexterIdentity.accent
                            )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send message")
                }
            }
        }
        .padding(16)
        .background(DS.Colors.surface1.opacity(0.95))
    }

    private func submitMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messageText = ""
        companionManager.submitTextMessageToDexter(trimmed)
    }
}

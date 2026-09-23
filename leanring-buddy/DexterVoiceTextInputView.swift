//
//  DexterVoiceTextInputView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterVoiceTextInputView: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var typedMessageText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Message Dexter…", text: $typedMessageText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 0.5)
                    )
                    .onSubmit {
                        submitTypedMessage()
                    }

                Button(action: submitTypedMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(
                            typedMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? DS.Colors.textTertiary
                                : DS.Colors.accent
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .disabled(typedMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

        }
    }

    private func submitTypedMessage() {
        let trimmedMessage = typedMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        typedMessageText = ""
        companionManager.submitTextMessageToDexter(trimmedMessage)
    }
}

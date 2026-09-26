//
//  DexterThinkingIndicator.swift
//  leanring-buddy
//

import SwiftUI

struct DexterConversationThinkingIndicator: View {
    let profile: DexterProfile
    var characterState: DexterCharacterState = .thinking

    var body: some View {
        HStack(alignment: .top, spacing: DexterMessageMetrics.avatarToBubbleGap) {
            DexterCharacterImage(
                profile: profile,
                characterState: characterState,
                size: DexterAvatarSize.md,
                animationEnabled: true
            )

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { dotIndex in
                    Circle()
                        .fill(profile.accentColor.opacity(dotIndex == 1 ? 0.85 : 0.45))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, DexterMessageMetrics.horizontalPadding)
            .padding(.vertical, DexterMessageMetrics.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.messageBubble, style: .continuous)
                    .fill(DexterSurfaceColors.surface.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterRadii.messageBubble, style: .continuous)
                    .stroke(DexterSurfaceColors.border.opacity(0.5), lineWidth: 1)
            )

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.name), thinking")
    }
}

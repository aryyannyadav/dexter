//
//  DexterChatWorkspaceHeader.swift
//  leanring-buddy
//

import SwiftUI

struct DexterChatWorkspaceHeader: View {
    let profile: DexterProfile?
    var characterState: DexterCharacterState
    var onOpenProfile: (() -> Void)?
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: DexterSpacing.md) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DexterColors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .accessibilityLabel("Back")
            }

            if let profile {
                Button(action: { onOpenProfile?() }) {
                    HStack(alignment: .center, spacing: DexterSpacing.sm) {
                        DexterCharacterImage(
                            profile: profile,
                            characterState: characterState,
                            size: 34,
                            animationEnabled: true
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(profile.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(DexterSurfaceColors.textPrimary)
                            Text(profile.displayRole)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(DexterSurfaceColors.textMuted)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .accessibilityLabel("\(profile.name) profile")
            }

            Spacer(minLength: 0)

            if onBack != nil {
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, DexterSpacing.xl)
        .padding(.vertical, DexterSpacing.sm + 2)
        .background(DexterSurfaceColors.background.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DexterColors.borderSubtle.opacity(0.65))
                .frame(height: 1)
        }
    }
}

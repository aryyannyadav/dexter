//
//  DexterAvatar.swift
//  leanring-buddy
//

import SwiftUI

/// Compact profile avatar — transparent `DexterCharacterImage` (no tile).
struct DexterAvatar: View {
    enum VisualState: Equatable {
        case normal
        case highlighted
        case muted
    }

    let profile: DexterProfile
    var size: CGFloat = DexterAvatarSize.md
    var visualState: VisualState = .normal
    var showStatus: Bool = false
    var statusTone: DexterStatusDot.Tone = .active
    var characterState: DexterCharacterState = .idle
    var animationEnabled: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DexterCharacterImage(
                profile: profile,
                characterState: characterState,
                size: size,
                animationEnabled: animationEnabled,
                isHovered: visualState == .highlighted
            )
            .opacity(visualState == .muted ? 0.55 : 1)

            if showStatus {
                DexterStatusDot(tone: statusTone, showsSoftGlow: false)
                    .offset(x: size * 0.08, y: size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(!animationEnabled)
        .accessibilityLabel("\(profile.name), \(characterState.accessibilityLabel)")
    }
}

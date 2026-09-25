//
//  DexterAvatar.swift
//  leanring-buddy
//

import SwiftUI

/// Compact profile avatar — renders through `DexterCharacterView` (phase 4).
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
            if let definition = resolvedCharacterDefinition {
                DexterCharacterView(
                    definition: definition,
                    appearance: profile.characterAppearance,
                    state: characterState,
                    size: .custom(size),
                    presentationMode: DexterCharacterAssetCatalog.presentationModeForCompactSurfaces(state: characterState),
                    animationEnabled: animationEnabled,
                    profileNameForAccessibility: animationEnabled ? profile.name : nil
                )
                .opacity(visualState == .muted ? 0.55 : 1)
                .scaleEffect(visualState == .highlighted ? 1.04 : 1)
                .overlay {
                    if visualState == .highlighted {
                        Circle()
                            .stroke(profile.accentColor.opacity(0.65), lineWidth: 2)
                    }
                }
            }

            if showStatus {
                DexterStatusDot(tone: statusTone, showsSoftGlow: false)
                    .offset(x: size * 0.08, y: size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(!animationEnabled)
        .accessibilityLabel("\(profile.name), \(characterState.accessibilityLabel)")
    }

    private var resolvedCharacterDefinition: DexterCharacterDefinition? {
        if let definition = DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID) {
            return definition
        }
        let fallbackID = DexterCharacterCatalog.defaultCharacterID(forProfileID: profile.id)
        return DexterCharacterCatalog.character(withID: fallbackID)
    }
}

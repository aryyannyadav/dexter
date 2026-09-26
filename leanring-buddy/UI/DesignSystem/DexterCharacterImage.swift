//
//  DexterCharacterImage.swift
//  leanring-buddy
//
//  Canonical transparent Dexter PNG — no tile, border, or background by default.
//

import SwiftUI

struct DexterCharacterImage: View {
    let profile: DexterProfile
    var characterState: DexterCharacterState = .idle
    var size: CGFloat = 36
    var artworkMagnification: CGFloat?
    var animationEnabled: Bool = false
    var isHovered: Bool = false

    var body: some View {
        Group {
            if let definition = resolvedDefinition {
                DexterCharacterView(
                    definition: definition,
                    appearance: profile.characterAppearance,
                    state: characterState,
                    size: .custom(size * 0.94),
                    presentationMode: .stage,
                    artworkMagnification: resolvedMagnification,
                    animationEnabled: animationEnabled,
                    profileNameForAccessibility: nil
                )
            }
        }
        .frame(width: size, height: size, alignment: .center)
        .scaleEffect(isHovered && !DexterMotionPreferences.shouldReduceMotion ? 1.04 : 1)
        .animation(DexterSuggestionMotion.hoverEase, value: isHovered)
        .accessibilityHidden(true)
    }

    private var resolvedMagnification: CGFloat {
        if let artworkMagnification {
            return artworkMagnification
        }
        if size <= 34 {
            return 1.28
        }
        if size <= 44 {
            return 1.24
        }
        return 1.20
    }

    private var resolvedDefinition: DexterCharacterDefinition? {
        if let definition = DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID) {
            return definition
        }
        return DexterCharacterCatalog.character(
            withID: DexterCharacterCatalog.defaultCharacterID(forProfileID: profile.id)
        )
    }
}

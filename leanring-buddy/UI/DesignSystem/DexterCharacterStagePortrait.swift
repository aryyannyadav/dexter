//
//  DexterCharacterStagePortrait.swift
//  leanring-buddy
//

import SwiftUI

/// Large illustrated character with ambient glow (Home hero, profile, collection cards).
struct DexterCharacterStagePortrait: View {
    let profile: DexterProfile
    var characterState: DexterCharacterState = .idle
    var height: CGFloat = 300
    var animationEnabled: Bool = true

    private var usesIllustratedStateArtwork: Bool {
        DexterCharacterAssetCatalog.hasAsset(
            named: DexterCharacterAssetCatalog.stateAssetName(for: characterState)
        )
    }

    var body: some View {
        ZStack {
            if !usesIllustratedStateArtwork {
                RadialGradient(
                    colors: [
                        profile.accentColor.opacity(0.35),
                        profile.accentColor.opacity(0.12),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: height * 0.55
                )
                .frame(width: height * 1.15, height: height * 0.85)
            } else {
                RadialGradient(
                    colors: [
                        profile.accentColor.opacity(0.14),
                        profile.accentColor.opacity(0.04),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: height * 0.5
                )
                .frame(width: height * 1.05, height: height * 0.75)
            }

            if let definition = resolvedDefinition {
                DexterCharacterView(
                    definition: definition,
                    appearance: profile.characterAppearance,
                    state: characterState,
                    size: .custom(height),
                    presentationMode: .stage,
                    animationEnabled: animationEnabled,
                    profileNameForAccessibility: profile.name
                )
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
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

//
//  DexterNotchActiveCharacterView.swift
//  leanring-buddy
//

import SwiftUI

/// Active Dexter character for ambient surfaces (notch, HUD).
struct DexterNotchActiveCharacterView: View {
    @ObservedObject var companionManager: CompanionManager
    var characterState: DexterCharacterState
    var size: DexterCharacterSize
    var presentationMode: DexterCharacterPresentationMode = .avatar
    var animationEnabled: Bool = true

    var body: some View {
        if let profile = companionManager.dexterProfileStore.activeProfile,
           let definition = resolvedDefinition(for: profile) {
            DexterCharacterView(
                definition: definition,
                appearance: profile.characterAppearance,
                state: characterState,
                size: size,
                presentationMode: presentationMode,
                animationEnabled: animationEnabled,
                profileNameForAccessibility: nil
            )
            .accessibilityHidden(true)
        } else if let definition = DexterCharacterCatalog.character(withID: DexterCharacterCatalog.personalCharacterID) {
            DexterCharacterView(
                definition: definition,
                appearance: DexterCharacterAppearance.defaultAppearance(forCharacterID: definition.id),
                state: characterState,
                size: size,
                presentationMode: DexterCharacterAssetCatalog.presentationModeForCompactSurfaces(state: characterState),
                animationEnabled: animationEnabled,
                profileNameForAccessibility: nil
            )
            .accessibilityHidden(true)
        } else {
            DexterLogo(size: size.pointLength, style: .standard, animated: animationEnabled && characterState != .idle)
                .accessibilityHidden(true)
        }
    }

    private func resolvedDefinition(for profile: DexterProfile) -> DexterCharacterDefinition? {
        if let definition = DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID) {
            return definition
        }
        let fallbackID = DexterCharacterCatalog.defaultCharacterID(forProfileID: profile.id)
        return DexterCharacterCatalog.character(withID: fallbackID)
    }
}

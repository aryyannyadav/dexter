//
//  DexterProfilePresentation.swift
//  leanring-buddy
//

import Foundation

/// Presentation bundle for future profile panel / notch (phase 4+).
struct DexterProfilePresentation: Equatable {
    let profile: DexterProfile
    let characterDefinition: DexterCharacterDefinition
    let appearance: DexterCharacterAppearance
    let liveCharacterState: DexterCharacterState

    var accessibilitySummary: String {
        "\(profile.name), \(liveCharacterState.accessibilityLabel)"
    }
}

enum DexterProfilePresentationBuilder {
    static func build(
        profile: DexterProfile,
        liveCharacterState: DexterCharacterState
    ) -> DexterProfilePresentation? {
        guard let definition = DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID)
            ?? DexterCharacterCatalog.character(withID: DexterCharacterCatalog.defaultCharacterID(forProfileID: profile.id))
        else {
            return nil
        }
        return DexterProfilePresentation(
            profile: profile,
            characterDefinition: definition,
            appearance: profile.characterAppearance,
            liveCharacterState: liveCharacterState
        )
    }
}

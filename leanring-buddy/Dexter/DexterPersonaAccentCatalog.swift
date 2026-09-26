//
//  DexterPersonaAccentCatalog.swift
//  leanring-buddy
//

import SwiftUI

/// Persona tint for avatar tiles only (never applied to the PNG).
enum DexterPersonaAccentCatalog {
    static func surfaceTint(for profile: DexterProfile) -> Color {
        switch profile.id {
        case DexterSeedProfileIdentifier.studyBuddy:
            return DexterPastelColors.lavender
        case DexterSeedProfileIdentifier.builder:
            return DexterPastelColors.sky
        case DexterSeedProfileIdentifier.researcher:
            return DexterPastelColors.suggestionYellow.opacity(0.85)
        case DexterSeedProfileIdentifier.personal:
            return DexterPastelColors.mint.opacity(0.9)
        default:
            return profile.accentColor
        }
    }
}

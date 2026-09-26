//
//  DexterDexterPersonaHeader.swift
//  leanring-buddy
//

import SwiftUI

struct DexterDexterPersonaHeader: View {
    let profile: DexterProfile
    var characterState: DexterCharacterState = .idle

    var body: some View {
        HStack(alignment: .center, spacing: DexterSpacing.md) {
            DexterCharacterImage(
                profile: profile,
                characterState: characterState,
                size: 40,
                animationEnabled: true
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(DexterTypography.sectionTitle())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                Text(profile.displayRole)
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

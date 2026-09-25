//
//  DexterCharacterStatePreviewSheet.swift
//  leanring-buddy
//

import SwiftUI

#if DEBUG
/// Validates state sheet assets on the Dexter dark background (development only).
struct DexterCharacterStatePreviewSheet: View {
    private let definition = DexterCharacterCatalog.coreCharacters.first!

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: DexterSpacing.xl
            ) {
                ForEach(DexterCharacterState.allCases, id: \.self) { characterState in
                    VStack(spacing: DexterSpacing.sm) {
                        DexterCharacterView(
                            definition: definition,
                            appearance: definition.defaultAppearance,
                            state: characterState,
                            size: .custom(200),
                            presentationMode: .stage,
                            animationEnabled: true,
                            profileNameForAccessibility: characterState.rawValue
                        )
                        .frame(height: 220)

                        Text(characterState.rawValue.uppercased())
                            .font(DexterTypography.metadata())
                            .foregroundColor(DexterSurfaceColors.textSecondary)
                    }
                    .padding(DexterSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                            .fill(DexterSurfaceColors.surface.opacity(0.35))
                    )
                }
            }
            .padding(DexterSpacing.xl)
        }
        .frame(minWidth: 520, minHeight: 640)
        .background(DexterSurfaceColors.background)
    }
}
#endif

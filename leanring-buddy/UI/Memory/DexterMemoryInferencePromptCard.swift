//
//  DexterMemoryInferencePromptCard.swift
//  leanring-buddy
//

import SwiftUI

struct DexterMemoryInferencePromptCard: View {
    let suggestion: DexterMemoryInferenceSuggestion
    var onRemember: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.sm) {
            Text("Remember this?")
                .font(DexterTypography.metadata())
                .foregroundColor(DexterSurfaceColors.textMuted)

            Text("“\(suggestion.suggestedContent)”")
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterSurfaceColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DexterSpacing.md) {
                Button("Remember", action: onRemember)
                    .buttonStyle(.plain)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterPastelColors.lavender)
                    .pointerCursor()

                Button("Not now", action: onDecline)
                    .buttonStyle(.plain)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
                    .pointerCursor()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dexterCompanionInlineBannerChrome()
    }
}

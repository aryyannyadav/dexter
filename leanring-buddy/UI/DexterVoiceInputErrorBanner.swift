//
//  DexterVoiceInputErrorBanner.swift
//  leanring-buddy
//

import SwiftUI

struct DexterVoiceInputErrorBanner: View {
    let presentation: DexterVoiceInputErrorPresentation
    let onOpenVoiceSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DexterSpacing.md) {
            Image(systemName: "mic.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DexterPastelColors.blush)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: DexterSpacing.xs) {
                Text(presentation.headline)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterSurfaceColors.textPrimary)

                Text(presentation.detail)
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if presentation.opensVoiceSettingsOnAction {
                    Button(DexterVoiceInputErrorPresentation.openVoiceSettingsButtonTitle) {
                        onOpenVoiceSettings()
                    }
                    .buttonStyle(.plain)
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterPastelColors.lavender)
                    .pointerCursor()
                }
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DexterSurfaceColors.textMuted)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DexterSurfaceColors.surface.opacity(0.8)))
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
        .dexterCompanionInlineBannerChrome()
    }
}

//
//  DexterQuickPromptChip.swift
//  leanring-buddy
//

import SwiftUI

/// Compact prompt chip (point-invoke / empty-state shortcuts — not contextual suggestions).
struct DexterQuickPromptChip: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DexterMetrics.space8) {
                Text(title)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterColors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: DexterMetrics.space8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isHovered ? DexterPastelColors.lavender : DexterColors.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DexterMetrics.space16)
            .padding(.vertical, DexterMetrics.space12)
            .background(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                    .fill(
                        isHovered
                            ? DexterPastelColors.lavender.opacity(0.12)
                            : DexterColors.cardBackground
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                    .stroke(isHovered ? DexterPastelColors.lavender.opacity(0.45) : DexterColors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
    }
}

//
//  DexterChatMessageContent.swift
//  leanring-buddy
//

import SwiftUI

/// Readable chat copy with consistent line height and paragraph spacing.
struct DexterChatMessageContent: View {
    let text: String
    var foregroundColor: Color = DexterColors.textPrimary
    var isError: Bool = false

    var body: some View {
        if isError {
            errorContent
        } else {
            DexterChatMarkdownText(
                text: text,
                foregroundColor: foregroundColor,
                isError: false
            )
        }
    }

    private var errorContent: some View {
        HStack(alignment: .top, spacing: DexterMetrics.space10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DexterColors.warning)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: DexterMetrics.space8) {
                Text("Something didn’t work")
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterColors.textPrimary)

                DexterChatMarkdownText(text: text, foregroundColor: DexterColors.textSecondary, isError: true)
            }
        }
        .padding(DexterMetrics.space14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                .fill(DexterColors.warning.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                .stroke(DexterColors.warning.opacity(0.35), lineWidth: 1)
        )
    }
}

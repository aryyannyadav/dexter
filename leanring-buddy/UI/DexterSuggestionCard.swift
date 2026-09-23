//
//  DexterSuggestionCard.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSuggestionCard: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DexterIdentity.Typography.bodyMedium())
                .foregroundColor(DS.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                        .fill(isHovered ? DS.Colors.surface3 : DS.Colors.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                        .stroke(isHovered ? DexterIdentity.accentBorder : DS.Colors.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { isHovered = $0 }
        .accessibilityLabel(title)
    }
}

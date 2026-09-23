//
//  DexterContextIndicator.swift
//  leanring-buddy
//

import SwiftUI

struct DexterContextIndicator: View {
    let isScreenContextAvailable: Bool
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isScreenContextAvailable ? DexterIdentity.accent : DS.Colors.textTertiary.opacity(0.5))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Text(isScreenContextAvailable ? "Screen context available" : "Screen context unavailable")
                .font(compact ? DexterIdentity.Typography.monoCaption() : DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isScreenContextAvailable
                ? "Screen context available"
                : "Screen context unavailable"
        )
    }
}

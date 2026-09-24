//
//  DexterContextIndicator.swift
//  leanring-buddy
//

import SwiftUI

struct DexterContextIndicator: View {
    let uiState: DexterScreenContextUIState
    var contextualLabel: String?
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Text(displayLabel)
                .font(compact ? DexterIdentity.Typography.monoCaption() : DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
                .lineLimit(compact ? 1 : 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayLabel)
    }

    private var displayLabel: String {
        if let contextualLabel, !contextualLabel.isEmpty {
            return contextualLabel
        }
        return uiState.userFacingLabel
    }

    private var indicatorColor: Color {
        switch uiState {
        case .ready:
            return DexterIdentity.accent
        case .analyzingScreen:
            return DexterIdentity.accentSecondary
        case .permissionRequired:
            return DS.Colors.destructiveText.opacity(0.85)
        case .unavailable:
            return DS.Colors.textTertiary.opacity(0.5)
        }
    }
}

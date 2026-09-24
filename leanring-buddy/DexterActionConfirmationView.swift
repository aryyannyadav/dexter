//
//  DexterActionConfirmationView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterActionConfirmationPresentation: Equatable {
    let actionId: UUID
    let riskLevel: DexterActionRiskLevel
    let content: DexterActionConfirmationContent
}

struct DexterActionConfirmationView: View {
    let presentation: DexterActionConfirmationPresentation
    let onCancel: () -> Void
    let onAllow: () -> Void

    var body: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 12) {
                DexterSectionHeader(
                    title: "Permission",
                    subtitle: "Review before Dexter runs this action"
                )
                DexterStatusChip(label: presentation.riskLevel.rawValue, isActive: true)

                confirmationRow(title: "What", body: presentation.content.whatWillHappen)
                confirmationRow(title: "Why", body: presentation.content.whyDexterWantsToDoIt)
                confirmationRow(title: "Where", body: presentation.content.whereItWillHappen)
                if let recoveryWarning = presentation.content.recoveryWarning?.nonEmptyTrimmedValue {
                    confirmationRow(title: "Recovery", body: recoveryWarning)
                }

                HStack(spacing: 10) {
                    Button("Cancel", action: onCancel)
                        .dsOutlinedButtonStyle()
                    Button("Allow", action: onAllow)
                        .dsPrimaryButtonStyle()
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                .stroke(DexterIdentity.accentBorder, lineWidth: 1)
        )
    }

    private func confirmationRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(DexterIdentity.Typography.monoCaption())
                .foregroundColor(DS.Colors.textTertiary)
            Text(body)
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

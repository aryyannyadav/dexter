//
//  DexterSuggestionHeroActionPills.swift
//  leanring-buddy
//

import SwiftUI

/// Shared No / Adjust / Yes pills for hero suggestions (Home, notch, legacy adapters).
struct DexterSuggestionHeroActionPills: View {
    let primaryTitle: String
    var adjustOptions: [DexterSuggestionAdjustOption] = []
    let onDismiss: () -> Void
    let onPrimary: () -> Void
    var onAdjust: ((DexterSuggestionAdjustOption) -> Void)?

    var body: some View {
        HStack(spacing: DexterSpacing.sm) {
            pillButton(title: "No", isPrimary: false, action: onDismiss)

            if let onAdjust, !adjustOptions.isEmpty {
                Menu {
                    ForEach(Array(adjustOptions.enumerated()), id: \.offset) { _, option in
                        Button(option.title) { onAdjust(option) }
                    }
                } label: {
                    pillLabel(title: "Adjust", isPrimary: false)
                }
                .menuStyle(.borderlessButton)
                .pointerCursor()
            }

            pillButton(title: primaryTitle, isPrimary: true, action: onPrimary)
        }
    }

    private func pillButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pillLabel(title: title, isPrimary: isPrimary)
        }
        .buttonStyle(DexterSuggestionPillButtonStyle())
        .pointerCursor()
    }

    private func pillLabel(title: String, isPrimary: Bool) -> some View {
        Text(title)
            .font(DexterTypography.bodyMedium())
            .foregroundColor(isPrimary ? DexterColors.textPrimary : DexterColors.textSecondary)
            .padding(.horizontal, DexterSpacing.lg)
            .padding(.vertical, DexterSpacing.sm)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isPrimary
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        DexterPastelColors.sky.opacity(0.5),
                                        DexterPastelColors.lavender.opacity(0.45)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            : AnyShapeStyle(DexterSurfaceColors.surfaceElevated)
                    )
            )
    }
}

//
//  DexterHomeDexterCardView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeDexterCardView: View {
    let profile: DexterProfile
    let recentActivityLine: String?
    let workSuggestion: DexterProfileWorkSuggestion?
    let onOpen: () -> Void
    var onOpenProfile: (() -> Void)?
    var onPrimarySuggestion: (() -> Void)?

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                characterHeader
                detailsFooter
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                    .stroke(
                        isHovered ? profile.accentColor.opacity(0.5) : DexterSurfaceColors.border.opacity(0.35),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.22 : 0.12),
                radius: isHovered ? 14 : 8,
                y: isHovered ? 8 : 4
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.015 : 1))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(DexterAnimation.fastSpring, value: isHovered)
        .animation(DexterAnimation.fastSpring, value: isPressed)
        .pointerCursor()
        .accessibilityLabel("\(profile.name), \(profile.displayRole)")
        .contextMenu {
            Button("Open workspace", action: onOpen)
            if let onOpenProfile {
                Button("View profile", action: onOpenProfile)
            }
        }
    }

    private var characterHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    profile.accentColor.opacity(0.28),
                    profile.accentColor.opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 148)

            DexterCharacterStagePortrait(
                profile: profile,
                characterState: .idle,
                height: 132,
                animationEnabled: isHovered
            )
            .offset(y: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 148)
    }

    private var detailsFooter: some View {
        HStack(alignment: .top, spacing: DexterSpacing.md) {
            VStack(alignment: .leading, spacing: DexterSpacing.xs) {
                Text(profile.name)
                    .font(DexterTypography.cardTitle())
                    .foregroundColor(DexterColors.textPrimary)

                Text(profile.displayRole)
                    .font(DexterTypography.secondary())
                    .foregroundColor(profile.accentColor.opacity(0.95))
                    .lineLimit(2)

                if let recentActivityLine {
                    Text(recentActivityLine)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }

                if let workSuggestion, let onPrimarySuggestion {
                    Button(action: onPrimarySuggestion) {
                        Text(workSuggestion.primaryActionTitle)
                            .font(DexterTypography.metadata())
                            .foregroundColor(DexterColors.textPrimary)
                            .padding(.horizontal, DexterSpacing.md)
                            .padding(.vertical, DexterSpacing.xs)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                DexterPastelColors.sky.opacity(0.35),
                                                DexterPastelColors.lavender.opacity(0.3)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DexterSpacing.sm)
                    .pointerCursor()
                    .accessibilityLabel(workSuggestion.primaryActionTitle)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DexterColors.textTertiary)
                .padding(.top, 4)
        }
        .padding(DexterSpacing.lg)
        .background(DexterSurfaceColors.surfaceElevated.opacity(0.92))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
            .fill(DexterSurfaceColors.surface)
    }
}

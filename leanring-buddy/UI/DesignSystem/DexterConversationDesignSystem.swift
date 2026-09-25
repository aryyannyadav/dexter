//
//  DexterConversationDesignSystem.swift
//  leanring-buddy
//
//  Phase 1 — tokens for the character-driven messaging Home redesign.
//  Views should consume these instead of ad-hoc magic numbers (phases 2+).
//

import SwiftUI

// MARK: - Spacing scale (reference: airy sidebar + compact chat)

enum DexterSpacing {
    static let xs: CGFloat = DexterMetrics.space4
    static let sm: CGFloat = DexterMetrics.space8
    static let md: CGFloat = DexterMetrics.space12
    static let lg: CGFloat = DexterMetrics.space16
    static let xl: CGFloat = DexterMetrics.space24
    static let xxl: CGFloat = DexterMetrics.space32
}

// MARK: - Corner radii

enum DexterRadii {
    static let small: CGFloat = DexterMetrics.radiusSmall
    static let medium: CGFloat = DexterMetrics.radiusMedium
    static let large: CGFloat = DexterMetrics.radiusLarge
    /// Primary dashboard / Dexter profile cards (reference ~18–20pt).
    static let card: CGFloat = 18
    static let pill: CGFloat = DexterMetrics.radiusPill
    /// Soft selection pill in sidebar (reference ~10–12pt).
    static let selectionSurface: CGFloat = 10
    /// iMessage-style bubble base (subtle, not oversized).
    static let messageBubble: CGFloat = 14
    static let messageBubbleTight: CGFloat = 6
}

// MARK: - Layout (reference proportions)

enum DexterConversationLayout {
    /// Sidebar ~22–25% of a typical Home window (reference screenshots).
    static let sidebarWidth: CGFloat = 272
    static let sidebarWidthCompact: CGFloat = 248
    static let headerHeight: CGFloat = 52
    static let chatColumnMaxWidth: CGFloat = 720
    static let composerMinHeight: CGFloat = 56
    static let composerMaxHeight: CGFloat = 120
    static let composerBottomInset: CGFloat = DexterSpacing.lg
    static let messageColumnHorizontalPadding: CGFloat = DexterSpacing.xl
    static let messageStackSpacing: CGFloat = DexterSpacing.sm
    /// Gap between speaker groups (reference: more air between turns).
    static let messageGroupSpacing: CGFloat = DexterSpacing.lg
    static let suggestionCarouselHeight: CGFloat = 220
    static let profileSheetWidth: CGFloat = 320
}

// MARK: - Avatars

enum DexterAvatarSize {
    static let xs: CGFloat = 20
    static let sm: CGFloat = 28
    static let md: CGFloat = 36
    static let lg: CGFloat = 48
    static let xl: CGFloat = 72
    static let hero: CGFloat = 120
}

// MARK: - Message bubbles

enum DexterMessageMetrics {
    static let compactMaxWidthRatio: CGFloat = 0.52
    static let regularMaxWidthRatio: CGFloat = 0.62
    static let userBubbleAbsoluteMaxWidth: CGFloat = 380
    static let assistantBubbleAbsoluteMaxWidth: CGFloat = 560
    static let horizontalPadding: CGFloat = DexterSpacing.md
    static let verticalPadding: CGFloat = DexterSpacing.sm + 2
    static let tailSize: CGFloat = 6
    static let avatarToBubbleGap: CGFloat = DexterSpacing.sm
    /// Within-group spacing (same speaker, short window).
    static let intraGroupSpacing: CGFloat = 3
}

// MARK: - Composer / voice pill (visual only; STT unchanged)

enum DexterComposerMetrics {
    static let voicePillHeight: CGFloat = 44
    static let textFieldHeight: CGFloat = 40
    static let iconSize: CGFloat = 18
    static let horizontalPadding: CGFloat = DexterSpacing.lg
    static let interControlSpacing: CGFloat = DexterSpacing.sm
}

// MARK: - Pastel / gel accents (derived from Dexter logo warmth + companion cyan)

enum DexterPastelColors {
    static let coral = Color(hex: "#F4A88A")
    static let peach = Color(hex: "#F7C9A8")
    static let cream = Color(hex: "#F5E6D8")
    static let blush = Color(hex: "#F2B5C6")
    static let lavender = Color(hex: "#C4B5FD")
    static let sky = Color(hex: "#93C5FD")
    static let mint = Color(hex: "#99F6E4")
    static let suggestionBlue = Color(hex: "#B8D4F0")
    static let suggestionYellow = Color(hex: "#F5E6A8")
    static let suggestionPink = Color(hex: "#F5C4D8")

    /// Soft sidebar selection fill (reference: glowing pastel pill).
    static let selectionFill = LinearGradient(
        colors: [
            Color(hex: "#5B8DEF").opacity(0.22),
            Color(hex: "#A78BFA").opacity(0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func suggestionSurface(for index: Int) -> Color {
        switch index % 3 {
        case 0: return suggestionBlue
        case 1: return suggestionYellow
        default: return suggestionPink
        }
    }
}

// MARK: - Semantic surface aliases (maps existing dark palette)

enum DexterSurfaceColors {
    static let background = DexterColors.background
    static let secondaryBackground = DexterColors.sidebarBackground
    static let surface = DexterColors.cardBackground
    static let surfaceElevated = DexterColors.cardBackgroundElevated
    static let surfaceHover = DexterColors.hoverOverlay
    static let surfaceSelected = DexterColors.selectedOverlay
    static let border = DexterColors.border
    static let textPrimary = DexterColors.textPrimary
    static let textSecondary = DexterColors.textSecondary
    static let textMuted = DexterColors.textMuted
    static let accent = DexterPastelColors.lavender
    static let success = DexterColors.success
    static let warning = DexterColors.warning
    static let error = DexterColors.error
}

// MARK: - Interaction

enum DexterInteractionOpacity {
    static let hover: CGFloat = 0.06
    static let pressed: CGFloat = 0.1
    static let selectedFill: CGFloat = 0.12
}

// MARK: - Inline companion banners (chat / home — soft pastel, not utility cyan)

private struct DexterCompanionInlineBannerChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DexterSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DexterPastelColors.lavender.opacity(0.14),
                                DexterPastelColors.sky.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                    .stroke(DexterPastelColors.lavender.opacity(0.22), lineWidth: 1)
            )
    }
}

extension View {
    /// Soft inline banner chrome for Home chat (point ask, voice, tasks).
    func dexterCompanionInlineBannerChrome() -> some View {
        modifier(DexterCompanionInlineBannerChrome())
    }
}

enum DexterCompanionLayout {
    static let inlineBannerMaxWidth: CGFloat = 560
    static let composerCharacterOverlapHeight: CGFloat = 128
    static let composerTopInsetForCharacter: CGFloat = 52
}

//
//  DexterColors.swift
//  leanring-buddy
//
//  Canonical Dexter product palette (dark macOS, cyan signal accent).
//

import SwiftUI

enum DexterColors {
    // MARK: - Surfaces

    static let background = Color(hex: "#0B0C0D")
    static let backgroundElevated = Color(hex: "#101211")
    static let sidebarBackground = Color(hex: "#131415")
    static let cardBackground = Color(hex: "#171918")
    static let cardBackgroundElevated = Color(hex: "#1E201F")
    static let inputBackground = Color(hex: "#202221")
    static let hoverOverlay = Color.white.opacity(0.05)
    static let selectedOverlay = Color.white.opacity(0.09)

    // MARK: - Borders

    static let border = Color(hex: "#2A2D2C")
    static let borderSubtle = Color(hex: "#373B39")
    static let borderStrong = Color(hex: "#444947")

    // MARK: - Text

    static let textPrimary = Color(hex: "#ECEEED")
    static let textSecondary = Color(hex: "#ADB5B2")
    static let textTertiary = Color(hex: "#6B736F")
    static let textMuted = Color(hex: "#525956")
    static let textOnAccent = Color.white

    // MARK: - Brand accents

    /// Primary Dexter signal — companion cursor, key actions, logo (user accent in Settings).
    static var accentCyan: Color { Color(hex: DexterAppearanceSettingsStore.accentHexForRendering) }
    static var accentCyanDim: Color { accentCyan.opacity(0.65) }
    static var accentCyanSubtle: Color { accentCyan.opacity(0.12) }
    static var accentCyanBorder: Color { accentCyan.opacity(0.35) }

    /// Secondary blue for links, info, and depth.
    static let accentBlue = Color(hex: "#38BDF8")
    static let accentBlueDeep = Color(hex: "#2563EB")

    /// Legacy overlay companion tint (screen triangle).
    static let companionOverlayBlue = Color(hex: "#3380FF")

    // MARK: - Semantic

    static let success = Color(hex: "#34D399")
    static let warning = Color(hex: "#FFB224")
    static let error = Color(hex: "#FF6369")
    static let muted = Color(hex: "#3A3D3B")

    // MARK: - Glow (use sparingly)

    static let glowCyan = Color(hex: "#22D3EE").opacity(0.45)
    static let glowBlue = Color(hex: "#38BDF8").opacity(0.35)
}

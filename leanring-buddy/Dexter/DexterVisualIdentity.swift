//
//  DexterVisualIdentity.swift
//  leanring-buddy
//
//  Legacy panel / menu-bar tokens — graphite surfaces + companion pastel accent.
//

import SwiftUI

enum DexterIdentity {
    static let windowMinWidth: CGFloat = 640
    static let sidebarExpandedWidth: CGFloat = 240

    /// Companion product accent (pastel; user theme cyan remains on `DexterColors.accentCyan` for opt-in surfaces).
    static let accent = DexterPastelColors.lavender
    static let accentSecondary = DexterPastelColors.sky
    static let accentSubtle = DexterPastelColors.lavender.opacity(0.14)
    static let accentBorder = DexterPastelColors.lavender.opacity(0.38)

    static let panelWidth: CGFloat = 340
    static let panelCornerRadius: CGFloat = 14

    enum Typography {
        static func sectionLabel() -> Font {
            .system(size: 10, weight: .semibold, design: .rounded)
        }

        static func body() -> Font {
            .system(size: 12, weight: .regular, design: .default)
        }

        static func bodyMedium() -> Font {
            .system(size: 12, weight: .medium, design: .default)
        }

        static func title() -> Font {
            .system(size: 14, weight: .semibold, design: .rounded)
        }

        static func monoCaption() -> Font {
            .system(size: 10, weight: .medium, design: .monospaced)
        }
    }
}

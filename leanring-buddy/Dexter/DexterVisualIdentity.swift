//
//  DexterVisualIdentity.swift
//  leanring-buddy
//
//  Original Dexter brand tokens — graphite surfaces + signal cyan accent.
//

import SwiftUI

enum DexterIdentity {
    static let accent = Color(hex: "#22D3EE")
    static let accentSecondary = Color(hex: "#38BDF8")
    static let accentSubtle = Color(hex: "#22D3EE").opacity(0.12)
    static let accentBorder = Color(hex: "#22D3EE").opacity(0.35)

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

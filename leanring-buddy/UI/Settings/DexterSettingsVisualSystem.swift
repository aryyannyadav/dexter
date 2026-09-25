//
//  DexterSettingsVisualSystem.swift
//  leanring-buddy
//
//  Reference-aligned settings chrome (HeyClicky-style density on Dexter graphite).
//

import SwiftUI

enum DexterSettingsMetrics {
    static let windowDefaultWidth: CGFloat = 920
    static let windowDefaultHeight: CGFloat = 640
    static let windowMinimumWidth: CGFloat = 780
    static let windowMinimumHeight: CGFloat = 520

    static let sidebarWidth: CGFloat = 212
    static let shellCornerRadius: CGFloat = 10
    static let contentPaddingHorizontal: CGFloat = 36
    static let contentPaddingTop: CGFloat = 28
    static let contentMaxWidth: CGFloat = 640

    static let sectionSpacing: CGFloat = 28
    static let rowSpacing: CGFloat = 0
    static let rowHeight: CGFloat = 44
    static let rowCompactHeight: CGFloat = 36

    static let sidebarRowHeight: CGFloat = 30
    static let sidebarRowCornerRadius: CGFloat = 6
    static let sidebarSectionSpacing: CGFloat = 18
    static let sidebarHorizontalPadding: CGFloat = 12
    static let sidebarTopPadding: CGFloat = 20

    static let searchFieldHeight: CGFloat = 32
    static let searchFieldCornerRadius: CGFloat = 8

    static let dividerOpacity: Double = 0.35
    static let toggleScale: CGFloat = 0.72
}

enum DexterSettingsColors {
    static let windowBackground = Color(hex: "#0C0D0D")
    static let sidebarBackground = Color(hex: "#131415")
    static let contentBackground = Color(hex: "#101211")
    static let rowHover = Color.white.opacity(0.05)
    static let rowSelected = DexterPastelColors.lavender.opacity(0.14)
    static let separator = Color.white.opacity(0.08)
    static let searchFieldFill = Color(hex: "#1A1B1C")
    static let searchFieldBorder = Color.white.opacity(0.1)
}

enum DexterSettingsTypography {
    static func windowBrand() -> Font {
        .system(size: 13, weight: .semibold, design: .default)
    }

    static func sidebarSection() -> Font {
        .system(size: 10, weight: .semibold, design: .default)
    }

    static func sidebarRow() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }

    static func pageTitle() -> Font {
        .system(size: 26, weight: .semibold, design: .default)
    }

    static func pageSubtitle() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static func sectionTitle() -> Font {
        .system(size: 11, weight: .semibold, design: .default)
    }

    static func rowTitle() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static func rowSubtitle() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }

    static func secondaryValue() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }
}

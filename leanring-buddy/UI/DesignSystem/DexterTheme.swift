//
//  DexterTheme.swift
//  leanring-buddy
//
//  Single entry point for Dexter product chrome tokens.
//

import SwiftUI

enum DexterTheme {
    typealias Colors = DexterColors
    typealias Typography = DexterTypography
    typealias Metrics = DexterMetrics
    typealias Motion = DexterAnimation
    typealias Spacing = DexterSpacing
    typealias Radii = DexterRadii
    typealias Surfaces = DexterSurfaceColors
    typealias Pastel = DexterPastelColors
    typealias Shadow = DexterShadow
    typealias ConversationLayout = DexterConversationLayout
    typealias MessageMetrics = DexterMessageMetrics
    typealias AvatarSize = DexterAvatarSize
    typealias ComposerMetrics = DexterComposerMetrics

    /// Preferred color scheme for Dexter surfaces.
    @MainActor
    static var preferredColorScheme: ColorScheme? {
        DexterAppearanceSettingsStore.shared.appearanceMode.preferredColorScheme
    }
}

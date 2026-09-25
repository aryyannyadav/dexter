//
//  DexterOverlayAccentColor.swift
//  leanring-buddy
//

import SwiftUI

enum DexterOverlayAccentColor {
    @MainActor
    static var current: Color {
        let option = DexterCursorSettingsStore.shared.selectedAccentColor
        switch option {
        case .blue:
            return DexterPastelColors.sky
        case .pastelPink:
            return DexterPastelColors.blush
        case .companionLavender:
            return DexterPastelColors.lavender
        default:
            return option.swatchColor
        }
    }
}

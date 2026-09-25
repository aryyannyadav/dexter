//
//  DexterShadow.swift
//  leanring-buddy
//

import SwiftUI

enum DexterShadow {
    static func card(isElevated: Bool = false) -> (color: Color, radius: CGFloat, y: CGFloat) {
        if isElevated {
            return (Color.black.opacity(0.28), 14, 6)
        }
        return (Color.black.opacity(0.18), 10, 4)
    }

    static func ambientNotch() -> (color: Color, radius: CGFloat, y: CGFloat) {
        (Color.black.opacity(0.2), 8, 3)
    }

    static func composerFocus(accent: Color) -> (color: Color, radius: CGFloat, y: CGFloat) {
        (accent.opacity(0.35), 12, 0)
    }
}

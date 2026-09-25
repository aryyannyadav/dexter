//
//  DexterGlow.swift
//  leanring-buddy
//

import SwiftUI

struct DexterGlow: ViewModifier {
    var color: Color
    var radius: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}

extension View {
    func dexterGlow(
        color: Color = DexterPastelColors.lavender,
        radius: CGFloat = 8,
        opacity: Double = 0.35
    ) -> some View {
        modifier(DexterGlow(color: color, radius: radius, opacity: opacity))
    }
}

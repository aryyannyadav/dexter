//
//  DexterInteractiveModifiers.swift
//  leanring-buddy
//

import SwiftUI

struct DexterTactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(DexterAnimation.fastSpring, value: configuration.isPressed)
    }
}

struct DexterCardSurfaceModifier: ViewModifier {
    var accentColor: Color = DexterPastelColors.lavender
    var isHovered: Bool
    var cornerRadius: CGFloat = DexterRadii.card

    func body(content: Content) -> some View {
        let shadow = DexterShadow.card(isElevated: isHovered)
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DexterSurfaceColors.surfaceElevated,
                                DexterSurfaceColors.surface.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isHovered ? accentColor.opacity(0.42) : DexterSurfaceColors.border.opacity(0.55),
                        lineWidth: 1
                    )
            )
            .shadow(color: shadow.color, radius: shadow.radius, y: isHovered ? shadow.y + 2 : shadow.y)
            .scaleEffect(isHovered && !DexterMotionPreferences.shouldReduceMotion ? 1.01 : 1)
            .animation(DexterMotionPreferences.shouldReduceMotion ? nil : DexterAnimation.gentleEase, value: isHovered)
    }
}

extension View {
    func dexterCardSurface(
        accentColor: Color = DexterPastelColors.lavender,
        isHovered: Bool,
        cornerRadius: CGFloat = DexterRadii.card
    ) -> some View {
        modifier(DexterCardSurfaceModifier(accentColor: accentColor, isHovered: isHovered, cornerRadius: cornerRadius))
    }
}

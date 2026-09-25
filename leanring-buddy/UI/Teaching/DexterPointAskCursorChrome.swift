//
//  DexterPointAskCursorChrome.swift
//  leanring-buddy
//

import SwiftUI

/// Subtle halo around the Dexter triangle communicating Point + Ask presence.
struct DexterPointAskCursorChrome: View {
    let presenceState: DexterPointAskPresenceState

    @ObservedObject private var cursorAppearanceSettings = DexterCursorSettingsStore.shared
    @State private var pulsePhase: CGFloat = 0.85

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.35 + pulseStrength * 0.25), lineWidth: ringLineWidth)
                .frame(width: ringDiameter, height: ringDiameter)
                .blur(radius: presenceState == .thinking ? 0.5 : 0)

            if presenceState == .thinking {
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(
                        DexterPastelColors.lavender.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: ringDiameter + 6, height: ringDiameter + 6)
                    .rotationEffect(.degrees(pulsePhase * 360))
            }
        }
        .scaleEffect(presenceState == .targeted ? 1.02 : 1.0)
        .onAppear {
            withAnimation(DexterAnimation.logoBreathing) {
                pulsePhase = 1.0
            }
        }
        .accessibilityHidden(true)
    }

    private var ringDiameter: CGFloat {
        let styleDiameterBoost: CGFloat = cursorAppearanceSettings.selectedCursorStyle.loadsCharacterArtwork ? 8 : 0
        switch presenceState {
        case .ready:
            return 26 + styleDiameterBoost
        case .targeted:
            return 34 + styleDiameterBoost
        case .thinking:
            return 38 + styleDiameterBoost
        }
    }

    private var ringLineWidth: CGFloat {
        switch presenceState {
        case .ready:
            return 1
        case .targeted:
            return 1.5
        case .thinking:
            return 2
        }
    }

    private var ringColor: Color {
        switch presenceState {
        case .ready:
            return cursorAppearanceSettings.selectedAccentColor.swatchColor
        case .targeted:
            return DexterPastelColors.sky
        case .thinking:
            return DexterPastelColors.lavender
        }
    }

    private var pulseStrength: CGFloat {
        switch presenceState {
        case .ready:
            return 0.2
        case .targeted:
            return 0.55
        case .thinking:
            return 0.9
        }
    }
}

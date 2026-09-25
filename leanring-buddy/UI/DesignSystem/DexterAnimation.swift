//
//  DexterAnimation.swift
//  leanring-buddy
//

import SwiftUI

enum DexterAnimation {
    static let fast: Double = 0.15
    static let standard: Double = 0.25
    static let slow: Double = 0.4
    static let logoPulse: Double = 2.4

    static var fastSpring: Animation {
        .spring(response: 0.28, dampingFraction: 0.82)
    }

    static var standardSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.86)
    }

    static var gentleEase: Animation {
        .easeInOut(duration: standard)
    }

    static var logoBreathing: Animation {
        .easeInOut(duration: logoPulse).repeatForever(autoreverses: true)
    }

    static var avatarBreathe: Animation {
        .easeInOut(duration: 3.2).repeatForever(autoreverses: true)
    }

    static var avatarSleepBreathe: Animation {
        .easeInOut(duration: 4.8).repeatForever(autoreverses: true)
    }

    static var avatarThinkingGlow: Animation {
        .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
    }

    static var avatarSpeakingPulse: Animation {
        .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
    }

    static var avatarVerifySpin: Animation {
        .linear(duration: 1.4).repeatForever(autoreverses: false)
    }
}

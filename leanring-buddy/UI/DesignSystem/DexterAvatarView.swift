//
//  DexterAvatarView.swift
//  leanring-buddy
//

import SwiftUI

/// Reusable Dexter mark with state-driven micro-animations (subtle, technical).
struct DexterAvatarView: View {
    let size: CGFloat
    let state: DexterAvatarState
    var audioLevel: CGFloat = 0

    @State private var breatheScale: CGFloat = 1.0
    @State private var thinkingGlow: CGFloat = 0.55
    @State private var verifyRotation: Double = 0
    @State private var successPulse: CGFloat = 0

    var body: some View {
        ZStack {
            stateGlow

            DexterLogoTriangleShape()
                .fill(logoGradient)
                .frame(width: triangleSize, height: triangleSize)
                .rotationEffect(.degrees(35 + microTilt))
                .scaleEffect(breatheScale)
                .shadow(color: shadowColor, radius: size * 0.1, y: size * 0.02)
                .opacity(state == .sleeping ? 0.55 : 1)

            stateOverlay
        }
        .frame(width: size, height: size)
        .accessibilityLabel(state.accessibilityLabel)
        .onAppear { syncAnimationsForState(state) }
        .onChange(of: state) { _, newState in
            syncAnimationsForState(newState)
        }
        .onChange(of: audioLevel) { _, _ in
            guard state == .listening else { return }
            breatheScale = 1.0 + min(audioLevel, 1) * 0.04
        }
    }

    @ViewBuilder
    private var stateGlow: some View {
        switch state {
        case .thinking:
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            DexterPastelColors.lavender.opacity(0.35 * thinkingGlow),
                            DexterPastelColors.lavender.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.85
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .blur(radius: size * 0.08)
        case .listening:
            Circle()
                .stroke(DexterPastelColors.sky.opacity(0.25 + Double(min(audioLevel, 1)) * 0.35), lineWidth: 1)
                .frame(width: size * 1.15, height: size * 1.15)
        case .success:
            Circle()
                .stroke(DexterColors.success.opacity(0.5 + successPulse * 0.3), lineWidth: 1.5)
                .frame(width: size * 1.2, height: size * 1.2)
        case .error:
            Circle()
                .stroke(DexterColors.warning.opacity(0.65), lineWidth: 1.5)
                .frame(width: size * 1.18, height: size * 1.18)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch state {
        case .listening:
            DexterAvatarListeningBars(size: size, audioLevel: audioLevel)
        case .acting:
            ProgressView()
                .controlSize(.mini)
                .scaleEffect(0.65)
                .offset(y: size * 0.38)
        case .verifying:
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(DexterPastelColors.lavender.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: size * 1.05, height: size * 1.05)
                .rotationEffect(.degrees(verifyRotation))
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.22, weight: .bold))
                .foregroundColor(DexterColors.success.opacity(0.9))
                .offset(y: size * 0.42)
                .opacity(Double(successPulse))
        case .error:
            Image(systemName: "exclamationmark")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundColor(DexterColors.warning)
                .offset(y: size * 0.42)
        default:
            EmptyView()
        }
    }

    private var triangleSize: CGFloat {
        size * 0.78
    }

    private var microTilt: Double {
        switch state {
        case .acting, .verifying:
            return 2
        case .listening:
            return -1.5
        default:
            return 0
        }
    }

    private var logoGradient: LinearGradient {
        switch state {
        case .error:
            return LinearGradient(
                colors: [DexterColors.warning, DexterColors.error.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sleeping:
            return LinearGradient(
                colors: [DexterColors.textMuted, DexterColors.textTertiary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [DexterPastelColors.sky, DexterPastelColors.lavender],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        switch state {
        case .thinking, .listening:
            return DexterPastelColors.lavender.opacity(0.4)
        case .error:
            return DexterColors.warning.opacity(0.35)
        case .success:
            return DexterColors.success.opacity(0.35)
        default:
            return DexterPastelColors.sky.opacity(0.2)
        }
    }

    private func syncAnimationsForState(_ newState: DexterAvatarState) {
        switch newState {
        case .idle:
            breatheScale = 1.0
            withAnimation(DexterAnimation.avatarBreathe) {
                breatheScale = 1.03
            }
        case .sleeping:
            breatheScale = 1.0
            withAnimation(DexterAnimation.avatarSleepBreathe) {
                breatheScale = 1.02
            }
        case .thinking:
            thinkingGlow = 0.55
            withAnimation(DexterAnimation.avatarThinkingGlow) {
                thinkingGlow = 1.0
            }
        case .speaking:
            breatheScale = 1.0
            withAnimation(DexterAnimation.avatarSpeakingPulse) {
                breatheScale = 1.05
            }
        case .verifying:
            verifyRotation = 0
            withAnimation(DexterAnimation.avatarVerifySpin) {
                verifyRotation = 360
            }
        case .success:
            successPulse = 0
            withAnimation(DexterAnimation.gentleEase) {
                successPulse = 1
            }
        case .listening, .acting, .error:
            breatheScale = 1.0
        }
    }
}

/// Binds the avatar to live `CompanionManager` presence + mic level.
struct DexterAvatarCompanionView: View {
    @ObservedObject private var avatarPresence: DexterAvatarPresenceModel
    @ObservedObject private var companionManager: CompanionManager
    var size: CGFloat

    init(companionManager: CompanionManager, size: CGFloat) {
        self.companionManager = companionManager
        _avatarPresence = ObservedObject(wrappedValue: companionManager.dexterAvatarPresence)
        self.size = size
    }

    var body: some View {
        DexterAvatarView(
            size: size,
            state: avatarPresence.avatarState,
            audioLevel: companionManager.currentAudioPowerLevel
        )
    }
}

private struct DexterAvatarListeningBars: View {
    let size: CGFloat
    let audioLevel: CGFloat

    var body: some View {
        HStack(spacing: size * 0.05) {
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(DexterPastelColors.sky.opacity(0.85))
                    .frame(
                        width: size * 0.06,
                        height: barHeight(for: index)
                    )
            }
        }
        .offset(y: size * 0.42)
        .accessibilityHidden(true)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base = size * 0.08
        let level = min(max(audioLevel, 0.15), 1)
        let stagger = CGFloat(index) * 0.08
        return base + size * 0.14 * (level + stagger)
    }
}

/// Legacy triangle used only for animated voice avatar chrome (not brand mark).
struct DexterLogoTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        let height = side * sqrt(3.0) / 2.0
        let centerX = rect.midX
        let centerY = rect.midY

        let top = CGPoint(x: centerX, y: centerY - height / 1.5)
        let bottomLeft = CGPoint(x: centerX - side / 2, y: centerY + height / 3)
        let bottomRight = CGPoint(x: centerX + side / 2, y: centerY + height / 3)

        path.move(to: top)
        path.addLine(to: bottomLeft)
        path.addLine(to: bottomRight)
        path.closeSubpath()
        return path
    }
}

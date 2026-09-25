//
//  DexterCharacterView.swift
//  leanring-buddy
//

import SwiftUI

enum DexterCharacterPresentationMode {
    /// Circular avatar chrome (sidebar, chat).
    case avatar
    /// Full character for home / editor preview.
    case full
    /// Large illustrated character — transparent, no plate (Home hero / profile).
    case stage
}

enum DexterCharacterSize: Equatable {
    case tiny
    case small
    case medium
    case large
    case hero
    case custom(CGFloat)

    var pointLength: CGFloat {
        switch self {
        case .tiny: return 24
        case .small: return 36
        case .medium: return 64
        case .large: return 120
        case .hero: return 220
        case .custom(let value): return value
        }
    }
}

struct DexterCharacterView: View {
    let definition: DexterCharacterDefinition
    let appearance: DexterCharacterAppearance
    var state: DexterCharacterState = .idle
    var size: DexterCharacterSize = .medium
    var presentationMode: DexterCharacterPresentationMode = .avatar
    var animationEnabled: Bool = false
    var profileNameForAccessibility: String?

    @State private var animationPhase: Int = 0
    @State private var transientShake: CGFloat = 0
    @State private var blinkPhase: Bool = false

    var body: some View {
        let dimension = size.pointLength
        framedCharacter(dimension: dimension)
            .scaleEffect(animatedScale)
            .offset(y: animatedVerticalOffset)
            .offset(x: transientShake)
            .animation(animationsAllowed ? DexterCharacterMotion.animation(for: state) : nil, value: animationPhase)
            .animation(animationsAllowed ? DexterCharacterMotion.animation(for: state) : nil, value: state)
            .onChange(of: state) { _, newState in
                handleStateTransition(newState)
            }
            .onAppear {
                if animationsAllowed {
                    startIdlePhaseIfNeeded()
                }
            }
            .task(id: blinkTaskIdentity) {
                await runBlinkLoopIfNeeded()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHidden(profileNameForAccessibility == nil && !animationEnabled)
    }

    private var blinkTaskIdentity: String {
        "\(presentationMode)-\(animationEnabled)-\(state.rawValue)"
    }

    @ViewBuilder
    private func framedCharacter(dimension: CGFloat) -> some View {
        let core = ZStack {
            if usesLegacyPlateBackground {
                if presentationMode == .avatar {
                    Circle()
                        .fill(appearance.background.color.opacity(0.92))
                } else if presentationMode == .full {
                    RoundedRectangle(cornerRadius: DexterRadii.large, style: .continuous)
                        .fill(appearance.background.color.opacity(0.35))
                }
            }

            characterArtwork
                .padding(artworkPadding(for: dimension))
                .scaleEffect(y: blinkScale)
        }
        .frame(width: dimension, height: dimension)

        switch presentationMode {
        case .stage:
            core
        case .avatar:
            core
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(DexterSurfaceColors.border.opacity(0.45), lineWidth: 1)
                }
        case .full:
            core
                .clipShape(RoundedRectangle(cornerRadius: DexterRadii.large, style: .continuous))
        }
    }

    @ViewBuilder
    private var characterArtwork: some View {
        let assetName = DexterCharacterAssetCatalog.resolvedAssetName(
            definition: definition,
            appearance: appearance,
            state: state
        )
        if let image = DexterCharacterAssetCatalog.cachedImage(named: assetName) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
                .accessibilityLabel("Character artwork unavailable")
        }
    }

    private var usesStateSheetArtwork: Bool {
        DexterCharacterAssetCatalog.hasAsset(
            named: DexterCharacterAssetCatalog.stateAssetName(for: state)
        )
    }

    private var usesLegacyPlateBackground: Bool {
        presentationMode != .stage && !usesStateSheetArtwork
    }

    private func artworkPadding(for dimension: CGFloat) -> CGFloat {
        if usesStateSheetArtwork {
            switch presentationMode {
            case .stage: return dimension * 0.01
            case .avatar: return dimension * 0.04
            case .full: return dimension * 0.03
            }
        }
        switch presentationMode {
        case .avatar: return dimension * 0.1
        case .stage: return dimension * 0.02
        case .full: return dimension * 0.06
        }
    }

    private var blinkScale: CGFloat {
        guard !usesStateSheetArtwork else { return 1 }
        guard animationsAllowed, presentationMode == .stage || presentationMode == .full else { return 1 }
        return blinkPhase ? 0.985 : 1
    }

    private var animationsAllowed: Bool {
        animationEnabled && !DexterMotionPreferences.shouldReduceMotion
    }

    private func runBlinkLoopIfNeeded() async {
        guard animationsAllowed else { return }
        guard presentationMode == .stage || presentationMode == .full else { return }

        while !Task.isCancelled {
            let idleSeconds = Double.random(in: 3.2...6.5)
            try? await Task.sleep(nanoseconds: UInt64(idleSeconds * 1_000_000_000))
            guard !Task.isCancelled, animationsAllowed else { return }
            guard state == .idle || state == .sleeping else { continue }
            withAnimation(.easeInOut(duration: 0.08)) { blinkPhase = true }
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeInOut(duration: 0.1)) { blinkPhase = false }
        }
    }

    private var animatedScale: CGFloat {
        guard animationsAllowed else { return 1 }
        switch state {
        case .idle:
            return animationPhase == 0 ? 1.0 : 1.015
        case .listening:
            return 1.03
        case .thinking:
            return animationPhase == 0 ? 0.98 : 1.01
        case .speaking:
            return animationPhase == 0 ? 1.0 : 1.04
        case .working:
            return animationPhase == 0 ? 1.0 : 1.05
        case .success:
            return 1.08
        case .error:
            return 0.98
        case .sleeping:
            return 0.96
        }
    }

    private var animatedVerticalOffset: CGFloat {
        guard animationsAllowed else { return 0 }
        switch state {
        case .thinking:
            return animationPhase == 0 ? 0 : -2
        case .working:
            return animationPhase == 0 ? 0 : -3
        case .speaking:
            return animationPhase == 0 ? 0 : -1
        default:
            return 0
        }
    }

    private var accessibilityLabel: String {
        if let profileNameForAccessibility {
            return "\(profileNameForAccessibility), \(state.accessibilityLabel)"
        }
        return state.accessibilityLabel
    }

    private func startIdlePhaseIfNeeded() {
        guard animationsAllowed else { return }
        guard state == .idle || state == .sleeping else { return }
        animationPhase = 0
        withAnimation(DexterCharacterMotion.idleBreathing) {
            animationPhase = 1
        }
    }

    private func handleStateTransition(_ newState: DexterCharacterState) {
        guard animationsAllowed else { return }

        if newState == .error {
            withAnimation(.default) {
                transientShake = 4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.default) { transientShake = -4 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                withAnimation(.default) { transientShake = 0 }
            }
        }

        if newState == .success {
            withAnimation(DexterCharacterMotion.successPop) {
                animationPhase = 1
            }
        }

        if newState == .idle || newState == .sleeping {
            startIdlePhaseIfNeeded()
        } else {
            withAnimation(DexterCharacterMotion.animation(for: newState)) {
                animationPhase = animationPhase == 0 ? 1 : 0
            }
        }
    }
}

private struct AnyShape: Shape {
    private let builder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        builder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        builder(rect)
    }
}

enum DexterCharacterMotion {
    static let idleBreathing = Animation.easeInOut(duration: 2.6).repeatForever(autoreverses: true)
    static let successPop = Animation.easeOut(duration: 0.28)

    static func animation(for state: DexterCharacterState) -> Animation {
        switch state {
        case .idle, .sleeping:
            return idleBreathing
        case .listening:
            return .easeInOut(duration: 0.85).repeatForever(autoreverses: true)
        case .thinking:
            return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        case .speaking:
            return .easeInOut(duration: 0.45).repeatForever(autoreverses: true)
        case .working:
            return .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
        case .success:
            return successPop
        case .error:
            return .easeInOut(duration: 0.18)
        }
    }
}

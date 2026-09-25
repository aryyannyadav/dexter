//
//  DexterVoiceButton.swift
//  leanring-buddy
//

import SwiftUI

struct DexterVoiceButton: View {
    let interactionState: DexterVoiceInteractionState
    let audioPowerLevel: CGFloat
    let isPushToTalkEnabled: Bool
    let hasError: Bool
    var size: DexterVoiceButtonSize = .regular
    var prominence: DexterVoiceButtonProminence = .standard
    let onPress: () -> Void
    let onRelease: () -> Void

    enum DexterVoiceButtonProminence {
        case standard
        case primary
    }

    enum DexterVoiceButtonSize {
        case compact
        case regular

        var diameter: CGFloat {
            switch self {
            case .compact: return 40
            case .regular: return 52
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .compact: return 16
            case .regular: return 20
            }
        }
    }

    @State private var isPressed = false
    @State private var isHovered = false

    private var ringOpacity: Double {
        if hasError { return 0.45 }
        switch interactionState {
        case .listening: return 0.85
        case .transcribing, .thinking: return 0.55
        case .speaking: return 0.7
        case .error: return 0.75
        case .idle: return isHovered ? 0.35 : 0.2
        }
    }

    private var fillColor: Color {
        if hasError { return DexterColors.warning.opacity(0.14) }
        if !isPushToTalkEnabled { return DS.Colors.surface3 }
        switch interactionState {
        case .listening:
            return DexterIdentity.accent.opacity(0.35 + Double(min(audioPowerLevel, 1)) * 0.25)
        case .transcribing, .thinking, .speaking:
            return DexterIdentity.accentSubtle
        case .error:
            return DexterColors.warning.opacity(0.12)
        case .idle:
            if prominence == .primary {
                return isPressed || isHovered
                    ? DexterIdentity.accent.opacity(0.22)
                    : DexterIdentity.accent.opacity(0.14)
            }
            return isPressed || isHovered ? DS.Colors.surface3 : DS.Colors.surface2
        }
    }

    private var iconName: String {
        if hasError { return "mic.slash" }
        switch interactionState {
        case .listening: return "waveform"
        case .transcribing: return "waveform.badge.mic"
        case .thinking: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .idle: return "mic.fill"
        }
    }

    var body: some View {
        ZStack {
            if prominence == .primary && !hasError {
                Circle()
                    .fill(DexterPastelColors.lavender.opacity(isHovered || isPressed ? 0.2 : 0.12))
                    .frame(width: size.diameter + 14, height: size.diameter + 14)
                    .blur(radius: 6)
            }

            Circle()
                .stroke(ringColor.opacity(ringOpacity), lineWidth: ringLineWidth)
                .frame(width: size.diameter + ringPadding, height: size.diameter + ringPadding)
                .animation(.easeInOut(duration: 0.2), value: interactionState)

            Circle()
                .fill(fillColor)
                .frame(width: size.diameter, height: size.diameter)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: size.iconSize, weight: .semibold))
                        .foregroundColor(hasError ? DexterColors.warning : DexterIdentity.accent)
                        .symbolEffect(.variableColor.iterative, isActive: interactionState == .thinking)
                )
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isPushToTalkEnabled, !isPressed else { return }
                    isPressed = true
                    onPress()
                }
                .onEnded { _ in
                    guard isPressed else { return }
                    isPressed = false
                    onRelease()
                }
        )
        .onHover { isHovered = $0 }
        .pointerCursor()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var ringColor: Color {
        if hasError { return DexterColors.warning }
        return DexterIdentity.accent
    }

    private var ringLineWidth: CGFloat {
        if interactionState == .listening { return 2 }
        return prominence == .primary ? 1.5 : 1
    }

    private var ringPadding: CGFloat {
        prominence == .primary ? 8 : 6
    }

    private var accessibilityLabel: String {
        if hasError { return "Voice error" }
        switch interactionState {
        case .listening: return "Listening"
        case .transcribing: return "Transcribing"
        case .thinking: return "Processing"
        case .speaking: return "Speaking"
        case .error:
            return "Voice unavailable"
        case .idle:
            return isPushToTalkEnabled ? "Hold to talk" : "Push-to-talk disabled"
        }
    }
}

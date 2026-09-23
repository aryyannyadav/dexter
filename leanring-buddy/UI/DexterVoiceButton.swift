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
    let onPress: () -> Void
    let onRelease: () -> Void

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
        if hasError { return 0.9 }
        switch interactionState {
        case .listening: return 0.85
        case .thinking: return 0.55
        case .speaking: return 0.7
        case .idle: return isHovered ? 0.35 : 0.2
        }
    }

    private var fillColor: Color {
        if hasError { return DS.Colors.destructive.opacity(0.25) }
        if !isPushToTalkEnabled { return DS.Colors.surface3 }
        switch interactionState {
        case .listening:
            return DexterIdentity.accent.opacity(0.35 + Double(min(audioPowerLevel, 1)) * 0.25)
        case .thinking, .speaking:
            return DexterIdentity.accentSubtle
        case .idle:
            return isPressed || isHovered ? DS.Colors.surface3 : DS.Colors.surface2
        }
    }

    private var iconName: String {
        if hasError { return "exclamationmark.triangle.fill" }
        switch interactionState {
        case .listening: return "waveform"
        case .thinking: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        case .idle: return "mic.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DexterIdentity.accent.opacity(ringOpacity), lineWidth: interactionState == .listening ? 2 : 1)
                .frame(width: size.diameter + 6, height: size.diameter + 6)
                .animation(.easeInOut(duration: 0.2), value: interactionState)

            Circle()
                .fill(fillColor)
                .frame(width: size.diameter, height: size.diameter)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: size.iconSize, weight: .semibold))
                        .foregroundColor(hasError ? DS.Colors.destructiveText : DexterIdentity.accent)
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

    private var accessibilityLabel: String {
        if hasError { return "Voice error" }
        switch interactionState {
        case .listening: return "Listening"
        case .thinking: return "Processing"
        case .speaking: return "Speaking"
        case .idle:
            return isPushToTalkEnabled ? "Hold to talk" : "Push-to-talk disabled"
        }
    }
}

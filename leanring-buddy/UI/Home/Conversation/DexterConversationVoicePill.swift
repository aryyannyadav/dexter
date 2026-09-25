//
//  DexterConversationVoicePill.swift
//  leanring-buddy
//

import SwiftUI

/// Reference-style hold-to-talk capsule (voice wiring unchanged — press/release callbacks only).
struct DexterConversationVoicePill: View {
    let interactionState: DexterVoiceInteractionState
    let audioPowerLevel: CGFloat
    let isPushToTalkEnabled: Bool
    let hasError: Bool
    let shortcutLabel: String
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DexterSpacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
            Text(titleText)
                .font(DexterTypography.bodyMedium())
                .lineLimit(1)
        }
        .foregroundColor(DexterColors.textPrimary)
        .padding(.horizontal, DexterSpacing.lg)
        .padding(.vertical, DexterSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DexterPastelColors.sky.opacity(isListening ? 0.55 : 0.38),
                            DexterPastelColors.lavender.opacity(isListening ? 0.42 : 0.28)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(isListening ? 0.35 : 0.18), lineWidth: 1)
        )
        .shadow(
            color: DexterPastelColors.sky.opacity(isHovered || isListening ? 0.35 : 0.15),
            radius: isListening ? 14 : 8,
            y: 2
        )
        .scaleEffect(isPressed ? 0.98 : 1)
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
        .accessibilityLabel(isPushToTalkEnabled ? "Hold \(shortcutLabel) to talk" : "Push-to-talk disabled")
    }

    private var isListening: Bool {
        interactionState == .listening || interactionState == .transcribing
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

    private var titleText: String {
        if hasError { return "Voice unavailable" }
        if !isPushToTalkEnabled { return "Push-to-talk off" }
        switch interactionState {
        case .listening: return "Listening…"
        case .transcribing: return "Finishing…"
        case .thinking: return "Thinking…"
        case .speaking: return "Speaking…"
        case .idle: return "Hold \(shortcutLabel) to talk"
        case .error: return "Voice error"
        }
    }
}

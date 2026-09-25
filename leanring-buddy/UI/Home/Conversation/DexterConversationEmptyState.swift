//
//  DexterConversationEmptyState.swift
//  leanring-buddy
//

import SwiftUI

struct DexterConversationEmptyState: View {
    let profile: DexterProfile
    var highlightedFirstRunPrompt: String?
    let onSelectPrompt: (String) -> Void

    var body: some View {
        VStack(spacing: DexterSpacing.xl) {
            DexterCharacterStagePortrait(
                profile: profile,
                characterState: .idle,
                height: 200,
                animationEnabled: true
            )
            .padding(.top, DexterSpacing.md)

            VStack(spacing: DexterSpacing.sm) {
                Text("Hey, I'm \(profile.name).")
                    .font(DexterTypography.sectionTitle())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(profile.purpose)
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DexterSpacing.md) {
                    ForEach(Array(promptSuggestions.enumerated()), id: \.offset) { index, prompt in
                        DexterConversationPromptTile(
                            prompt: prompt,
                            accentIndex: index,
                            onSelect: { onSelectPrompt(prompt) }
                        )
                    }
                }
                .padding(.horizontal, DexterSpacing.sm)
            }
            .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DexterSpacing.xxl)
        .accessibilityElement(children: .contain)
    }

    private var promptSuggestions: [String] {
        if let highlightedFirstRunPrompt, !highlightedFirstRunPrompt.isEmpty {
            return [highlightedFirstRunPrompt]
        }
        return Array(DexterProfileConversationPrompts.suggestions(for: profile.id).prefix(3))
    }
}

private struct DexterConversationPromptTile: View {
    let prompt: String
    let accentIndex: Int
    let onSelect: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DexterSpacing.md) {
                Text(prompt)
                    .font(DexterTypography.messageCompact())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DexterPastelColors.sky)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.85)))
                }
            }
            .padding(DexterSpacing.lg)
            .frame(width: 168, height: 148, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                    .fill(DexterPastelColors.suggestionSurface(for: accentIndex).opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                    .stroke(Color.white.opacity(isHovered ? 0.22 : 0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.02 : 1))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(DexterAnimation.fastSpring, value: isHovered)
        .pointerCursor()
    }
}

enum DexterProfileConversationPrompts {
    static func suggestions(for profileId: UUID) -> [String] {
        switch profileId {
        case DexterSeedProfileIdentifier.studyBuddy:
            return ["Explain this C++ topic", "Quiz me on what I'm reading", "Help me study for my exam"]
        case DexterSeedProfileIdentifier.builder:
            return ["Help me debug this build", "Review my architecture plan", "What should I ship next?"]
        case DexterSeedProfileIdentifier.researcher:
            return ["Summarize this page", "Compare these sources", "What should I read next?"]
        default:
            return ["What should I focus on today?", "Catch me up on my tasks", "Help me plan my week"]
        }
    }
}

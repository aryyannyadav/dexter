//
//  DexterConversationEmptyState.swift
//  leanring-buddy
//

import SwiftUI

struct DexterConversationEmptyState: View {
    @ObservedObject var companionManager: CompanionManager
    let profile: DexterProfile
    var highlightedFirstRunPrompt: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.xl) {
            DexterDexterPersonaHeader(profile: profile, characterState: .idle)

            if let highlightedFirstRunPrompt, !highlightedFirstRunPrompt.isEmpty {
                firstRunHighlightedCard(prompt: highlightedFirstRunPrompt)
            }

            DexterHomeSuggestionsSection(
                companionManager: companionManager,
                sectionTitle: "Suggested for you",
                showsEmptyStateWhenNoSuggestions: true,
                layout: .centerStage,
                scope: .dexterProfile(profile.id)
            )
        }
        .frame(maxWidth: min(680, DexterConversationLayout.chatColumnMaxWidth))
        .frame(maxWidth: .infinity)
        .padding(.vertical, DexterSpacing.lg)
        .accessibilityElement(children: .contain)
    }

    private func firstRunHighlightedCard(prompt: String) -> some View {
        Button {
            companionManager.pendingOnboardingFirstSuggestionPrompt = nil
            companionManager.pendingOnboardingComposerPlaceholder = nil
            companionManager.submitTextMessageToDexter(prompt)
        } label: {
            HStack(spacing: DexterSpacing.md) {
                DexterCharacterImage(
                    profile: profile,
                    characterState: .listening,
                    size: 44
                )
                Text(prompt)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(DexterSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                    .fill(profile.accentColor.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

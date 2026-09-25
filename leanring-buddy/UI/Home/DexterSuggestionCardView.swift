//
//  DexterSuggestionCardView.swift
//  leanring-buddy
//

import SwiftUI

/// Legacy adapter — renders `DexterSuggestion` through the unified hero card.
struct DexterSuggestionCardView: View {
    @ObservedObject var companionManager: CompanionManager
    let suggestion: DexterSuggestion
    let onDismiss: () -> Void
    let onAccept: () -> Void

    private var item: DexterHomeSuggestionItem {
        .context(suggestion)
    }

    private var profile: DexterProfile? {
        guard let profileId = suggestion.dexterProfileId else {
            return companionManager.dexterProfileStore.activeProfile
        }
        return companionManager.dexterProfileStore.profile(withId: profileId)
    }

    var body: some View {
        DexterSuggestionCard(
            item: item,
            profile: profile,
            status: companionManager.dexterSuggestionStore.presentationState.status(for: item.id),
            isPrimary: true,
            usesHeroPresentation: true,
            onPrimaryAction: onAccept,
            onSecondaryAction: onDismiss,
            onAdjust: { option in
                companionManager.dexterSuggestionStore.acceptHomeSuggestion(
                    item,
                    userPromptOverride: option.userPrompt
                )
            },
            onDismiss: onDismiss,
            onRetry: {
                companionManager.dexterSuggestionStore.retryHomeSuggestion(item)
            }
        )
    }
}

//
//  DexterProfileWorkSuggestionCardView.swift
//  leanring-buddy
//

import SwiftUI

/// Legacy adapter — profile-work suggestions use the same hero card as Home.
struct DexterProfileWorkSuggestionCardView: View {
    @ObservedObject var companionManager: CompanionManager
    let profile: DexterProfile?
    let suggestion: DexterProfileWorkSuggestion
    let onPrimaryAction: () -> Void
    let onDismiss: () -> Void

    private var item: DexterHomeSuggestionItem {
        .profileWork(suggestion)
    }

    var body: some View {
        DexterSuggestionCard(
            item: item,
            profile: profile,
            status: companionManager.dexterSuggestionStore.presentationState.status(for: item.id),
            isPrimary: true,
            usesHeroPresentation: true,
            onPrimaryAction: onPrimaryAction,
            onSecondaryAction: onDismiss,
            onAdjust: nil,
            onDismiss: onDismiss,
            onRetry: {
                companionManager.dexterSuggestionStore.retryHomeSuggestion(item)
            }
        )
    }
}

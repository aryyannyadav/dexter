//
//  DexterHomeSuggestionsSection.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeSuggestionsSection: View {
    @ObservedObject var companionManager: CompanionManager
    var sectionTitle: String = "Suggested for you"
    var showsEmptyStateWhenNoSuggestions: Bool = true
    var layout: DexterSuggestionCarousel.Layout = .centerStage
    var marksSuggestionsReadOnAppear: Bool = false

    private var items: [DexterHomeSuggestionItem] {
        companionManager.dexterSuggestionStore.presentationState.homeSuggestions
    }

    var body: some View {
        VStack(alignment: .center, spacing: DexterSpacing.md) {
            if !items.isEmpty {
                if !sectionTitle.isEmpty {
                    Text(sectionTitle)
                        .font(
                            layout == .centerStage
                                ? DexterTypography.sectionTitle()
                                : DexterTypography.section()
                        )
                        .foregroundColor(
                            layout == .centerStage
                                ? DexterColors.textPrimary
                                : DexterSurfaceColors.textMuted
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                DexterSuggestionCarousel(
                    companionManager: companionManager,
                    items: items,
                    layout: layout
                )
                .frame(maxWidth: .infinity)
            } else if showsEmptyStateWhenNoSuggestions {
                suggestionsEmptyState
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            companionManager.dexterSuggestionStore.refreshSuggestionsFromAuthorizedContext()
            if marksSuggestionsReadOnAppear {
                companionManager.dexterSuggestionStore.markAllSuggestionsRead()
            }
        }
    }

    private var suggestionsEmptyState: some View {
        VStack(spacing: DexterSpacing.lg) {
            if let profile = companionManager.dexterProfileStore.activeProfile {
                DexterCharacterStagePortrait(
                    profile: profile,
                    characterState: .idle,
                    height: 160,
                    animationEnabled: true
                )
            }

            VStack(spacing: DexterSpacing.sm) {
                Text("Nothing to suggest right now.")
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Ask me anything, or open something I can help with.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .padding(.vertical, DexterSpacing.lg)
        .frame(maxWidth: .infinity)
    }
}

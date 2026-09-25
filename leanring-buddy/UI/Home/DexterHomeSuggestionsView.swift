//
//  DexterHomeSuggestionsView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeSuggestionsView: View {
    @ObservedObject var companionManager: CompanionManager

    private var items: [DexterHomeSuggestionItem] {
        companionManager.dexterSuggestionStore.presentationState.homeSuggestions
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DexterSpacing.xl) {
                headerBlock
                    .dexterHomeStaggeredEntrance(index: 0)

                DexterHomeSuggestionsSection(
                    companionManager: companionManager,
                    sectionTitle: "",
                    showsEmptyStateWhenNoSuggestions: true,
                    layout: .centerStage,
                    marksSuggestionsReadOnAppear: true
                )
                .dexterHomeStaggeredEntrance(index: 1)
            }
            .padding(.horizontal, DexterSpacing.xl)
            .padding(.vertical, DexterSpacing.xxl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(DexterSurfaceColors.background)
    }

    private var headerBlock: some View {
        VStack(spacing: DexterSpacing.sm) {
            Text("Suggested for you")
                .font(DexterTypography.hero())
                .foregroundColor(DexterColors.textPrimary)
                .multilineTextAlignment(.center)

            if items.isEmpty {
                Text("Nothing to suggest right now.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
            } else {
                Text(
                    "\(items.count) idea\(items.count == 1 ? "" : "s"), ready when you are."
                )
                .font(DexterTypography.secondary())
                .foregroundColor(DexterColors.textTertiary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

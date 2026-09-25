//
//  DexterHomeDashboardView.swift
//  leanring-buddy
//

import SwiftUI

/// Centered Home dashboard — companion stage (not settings layout).
struct DexterHomeDashboardView: View {
    @ObservedObject var companionManager: CompanionManager
    var onOpenProfile: ((UUID) -> Void)?

    private let stageMaxWidth: CGFloat = 640

    var body: some View {
        ScrollView {
            VStack(spacing: DexterSpacing.xxl) {
                companionStage
                    .dexterHomeStaggeredEntrance(index: 0)

                greetingSection
                    .dexterHomeStaggeredEntrance(index: 1)

                companionStatusLine
                    .dexterHomeStaggeredEntrance(index: 2)

                suggestionsBlock
                    .dexterHomeStaggeredEntrance(index: 3)

                recentActivityBlock
                    .dexterHomeStaggeredEntrance(index: 4)

                myDextersBlock
                    .dexterHomeStaggeredEntrance(index: 5)
            }
            .padding(.horizontal, DexterSpacing.xl)
            .padding(.top, DexterSpacing.xxl)
            .padding(.bottom, DexterSpacing.xxl + 80)
            .frame(maxWidth: stageMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private var greetingSection: some View {
        VStack(spacing: DexterSpacing.sm) {
            Text(DexterHomeGreetingFormatter.greeting(firstName: companionManager.dexterHomeUserFirstName))
                .font(DexterTypography.hero())
                .foregroundColor(DexterColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("What are you working on?")
                .font(DexterTypography.sectionTitle())
                .foregroundColor(DexterColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var companionStage: some View {
        if let profile = heroProfile {
            DexterCharacterStagePortrait(
                profile: profile,
                characterState: companionManager.activeCharacterState,
                height: 280,
                animationEnabled: true
            )
            .transition(.scale.combined(with: .opacity))
            .animation(DexterAnimation.standardSpring, value: profile.id)
        }
    }

    private var companionStatusLine: some View {
        let suggestions = companionManager.dexterSuggestionStore.presentationState.homeSuggestions
        return Group {
            if suggestions.isEmpty {
                Text("Nothing to suggest right now.")
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterColors.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("\(suggestions.count) idea\(suggestions.count == 1 ? "" : "s"), ready when you are.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var suggestionsBlock: some View {
        DexterHomeSuggestionsSection(
            companionManager: companionManager,
            sectionTitle: "Suggested for you",
            showsEmptyStateWhenNoSuggestions: false,
            layout: .centerStage
        )
    }

    private var recentActivityBlock: some View {
        DexterHomeRecentActivitySection(
            companionManager: companionManager,
            profileId: nil,
            onViewAll: {
                companionManager.presentDexterActivityBrowser(profileId: nil)
            }
        )
    }

    private var myDextersBlock: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.lg) {
            VStack(spacing: DexterSpacing.xs) {
                Text("Your Dexters")
                    .font(DexterTypography.sectionTitle())
                    .foregroundColor(DexterColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Different minds for different parts of your life.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: DexterSpacing.lg) {
                ForEach(Array(companionManager.dexterProfileStore.profiles.enumerated()), id: \.element.id) { index, profile in
                    DexterHomeDexterCardView(
                        profile: profile,
                        recentActivityLine: recentActivityLine(for: profile),
                        workSuggestion: profile.workSuggestions.first,
                        onOpen: {
                            companionManager.openDexterProfileWorkspace(profileId: profile.id)
                        },
                        onOpenProfile: {
                            onOpenProfile?(profile.id)
                        },
                        onPrimarySuggestion: {
                            if let suggestion = profile.workSuggestions.first {
                                companionManager.executeProfileWorkSuggestion(suggestion)
                            }
                        }
                    )
                    .dexterHomeStaggeredEntrance(index: 6 + index)
                }
            }
        }
    }

    private var heroProfile: DexterProfile? {
        companionManager.dexterProfileStore.activeProfile
            ?? companionManager.dexterProfileStore.profiles.first
    }

    private func recentActivityLine(for profile: DexterProfile) -> String? {
        let profileRecents = companionManager.dexterRecentConversations
            .filter { $0.dexterProfileId == profile.id }
            .sorted { $0.lastUpdated > $1.lastUpdated }
        guard let recent = profileRecents.first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let when = formatter.localizedString(for: recent.lastUpdated, relativeTo: Date())
        return "\(recent.title) · \(when)"
    }
}

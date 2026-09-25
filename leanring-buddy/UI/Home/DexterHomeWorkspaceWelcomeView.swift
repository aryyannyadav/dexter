//
//  DexterHomeWorkspaceWelcomeView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeWorkspaceWelcomeView: View {
    @ObservedObject var companionManager: CompanionManager
    var onOpenProfile: ((UUID) -> Void)?

    var body: some View {
        switch companionManager.homeWorkspacePresentation {
        case .dashboard:
            DexterHomeDashboardView(
                companionManager: companionManager,
                onOpenProfile: onOpenProfile
            )
        case .dexterWorkspace(let profileId):
            if let profile = companionManager.dexterProfileStore.profile(withId: profileId) {
                dexterWorkspaceContent(profile: profile)
            }
        }
    }

    private func dexterWorkspaceContent(profile: DexterProfile) -> some View {
        VStack(alignment: .leading, spacing: DexterSpacing.xl) {
            DexterHomeRecentActivitySection(
                companionManager: companionManager,
                profileId: profile.id,
                onViewAll: {
                    companionManager.presentDexterActivityBrowser(profileId: profile.id)
                }
            )

            DexterHomeDexterCardView(
                profile: profile,
                recentActivityLine: nil,
                workSuggestion: nil,
                onOpen: {},
                onOpenProfile: onOpenProfile.map { handler in { handler(profile.id) } }
            )
            .allowsHitTesting(false)

            DexterHomeSuggestionsSection(
                companionManager: companionManager,
                showsEmptyStateWhenNoSuggestions: true,
                layout: .centerStage
            )
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DexterSpacing.xl)
    }
}

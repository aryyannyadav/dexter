//
//  DexterMyDextersGalleryView.swift
//  leanring-buddy
//

import SwiftUI

/// Full-width “My Dexters” gallery (sidebar section or dedicated navigation).
struct DexterMyDextersGalleryView: View {
    @ObservedObject var companionManager: CompanionManager
    var onOpenProfile: ((UUID) -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: DexterSpacing.xl) {
                VStack(spacing: DexterSpacing.sm) {
                    Text("Your Dexters")
                        .font(DexterTypography.display())
                        .foregroundColor(DexterColors.textPrimary)
                    Text("Different minds for different parts of your life.")
                        .font(DexterTypography.secondary())
                        .foregroundColor(DexterColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DexterSpacing.xl)
                .dexterHomeStaggeredEntrance(index: 0)

                VStack(spacing: DexterSpacing.lg) {
                    ForEach(Array(companionManager.dexterProfileStore.profiles.enumerated()), id: \.element.id) { index, profile in
                        DexterHomeDexterCardView(
                            profile: profile,
                            recentActivityLine: recentLine(for: profile),
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
                        .dexterHomeStaggeredEntrance(index: index + 1)
                    }
                }
            }
            .padding(.horizontal, DexterSpacing.xl)
            .padding(.bottom, DexterSpacing.xxl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(DexterSurfaceColors.background)
    }

    private func recentLine(for profile: DexterProfile) -> String? {
        let recents = companionManager.dexterRecentConversations
            .filter { $0.dexterProfileId == profile.id }
            .sorted { $0.lastUpdated > $1.lastUpdated }
        guard let recent = recents.first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "\(recent.title) · \(formatter.localizedString(for: recent.lastUpdated, relativeTo: Date()))"
    }
}

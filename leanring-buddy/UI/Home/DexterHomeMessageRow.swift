//
//  DexterHomeMessageRow.swift
//  leanring-buddy
//
//  Legacy single-message row — Home chat uses DexterConversationMessageGroupView.
//

import SwiftUI

struct DexterHomeMessageRow: View {
    @ObservedObject var companionManager: CompanionManager
    let message: DexterChatMessage
    var showsTypingIndicator: Bool = false
    var isStreaming: Bool = false

    var body: some View {
        let profile = resolvedProfile
        let group = DexterConversationMessageGroup(
            id: message.id,
            role: message.role,
            messages: [message],
            timestamp: nil,
            showsTimestamp: false
        )

        VStack(alignment: .leading, spacing: DexterSpacing.sm) {
            DexterConversationMessageGroupView(
                group: group,
                profile: profile,
                columnMaxWidth: DexterConversationLayout.chatColumnMaxWidth
            )

            if showsTypingIndicator {
                DexterConversationThinkingIndicator(profile: profile)
            }
        }
    }

    private var resolvedProfile: DexterProfile {
        switch companionManager.homeWorkspacePresentation {
        case .dashboard:
            return companionManager.dexterProfileStore.activeProfile
                ?? companionManager.dexterProfileStore.profiles.first!
        case .dexterWorkspace(let profileId):
            return companionManager.dexterProfileStore.profile(withId: profileId)
                ?? companionManager.dexterProfileStore.profiles.first!
        }
    }
}

//
//  DexterHomeChatComposerStack.swift
//  leanring-buddy
//

import SwiftUI

/// Reference-style composer with character overlapping the top edge (visual only).
struct DexterHomeChatComposerStack: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var messageText: String
    var activeProfile: DexterProfile?
    var characterState: DexterCharacterState
    var showsCharacterPeek: Bool

    var body: some View {
        ZStack(alignment: .top) {
            DexterHomeComposer(
                companionManager: companionManager,
                messageText: $messageText,
                activeProfile: activeProfile
            )
            .padding(.top, showsCharacterPeek ? DexterCompanionLayout.composerTopInsetForCharacter : 0)

            if showsCharacterPeek, let activeProfile {
                DexterCharacterStagePortrait(
                    profile: activeProfile,
                    characterState: characterState,
                    height: DexterCompanionLayout.composerCharacterOverlapHeight,
                    animationEnabled: true
                )
                .offset(y: -36)
                .allowsHitTesting(false)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DexterAnimation.standardSpring, value: showsCharacterPeek)
    }
}

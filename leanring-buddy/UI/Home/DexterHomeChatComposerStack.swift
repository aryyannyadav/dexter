//
//  DexterHomeChatComposerStack.swift
//  leanring-buddy
//

import SwiftUI

/// Chat composer — no floating character overlay (character lives in messages/header only).
struct DexterHomeChatComposerStack: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var messageText: String
    var activeProfile: DexterProfile?
    var characterState: DexterCharacterState
    var showsCharacterPeek: Bool

    var body: some View {
        DexterHomeComposer(
            companionManager: companionManager,
            messageText: $messageText,
            activeProfile: activeProfile
        )
    }
}

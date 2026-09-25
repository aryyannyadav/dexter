//
//  DexterHomeHeroCharacterView.swift
//  leanring-buddy
//

import SwiftUI

/// Large animated character for Home (legacy entry — prefer `DexterCharacterStagePortrait`).
struct DexterHomeHeroCharacterView: View {
    @ObservedObject var companionManager: CompanionManager
    var profile: DexterProfile?
    var characterState: DexterCharacterState = .idle

    var body: some View {
        if let profile {
            DexterCharacterStagePortrait(
                profile: profile,
                characterState: characterState,
                height: 260,
                animationEnabled: true
            )
        }
    }
}

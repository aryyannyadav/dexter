//
//  DexterSuggestionLeadingCharacter.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSuggestionLeadingCharacter: View {
    let profile: DexterProfile?
    var characterState: DexterCharacterState
    var showsCharacter: Bool = true
    var isHovered: Bool = false
    var animationEnabled: Bool = false
    var staggerIndex: Int = 0

    @State private var isCharacterVisible = false

    var body: some View {
        Group {
            if showsCharacter, let profile {
                DexterCharacterImage(
                    profile: profile,
                    characterState: characterState,
                    size: 64,
                    artworkMagnification: 1.18,
                    animationEnabled: animationEnabled,
                    isHovered: isHovered
                )
            }
        }
        .opacity(isCharacterVisible ? 1 : 0)
        .offset(y: isCharacterVisible ? 0 : 6)
        .onAppear {
            guard !DexterMotionPreferences.shouldReduceMotion else {
                isCharacterVisible = true
                return
            }
            let delay = DexterSuggestionMotion.staggerStep * Double(min(staggerIndex, 12))
            withAnimation(DexterSuggestionMotion.entranceSpring.delay(delay)) {
                isCharacterVisible = true
            }
        }
        .accessibilityHidden(true)
    }
}

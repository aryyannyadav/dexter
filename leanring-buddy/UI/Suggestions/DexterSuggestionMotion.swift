//
//  DexterSuggestionMotion.swift
//  leanring-buddy
//

import SwiftUI

enum DexterSuggestionMotion {
    static let staggerStep: Double = 0.045
    static let entranceSpring = Animation.spring(response: 0.45, dampingFraction: 0.86)
    static let hoverEase = Animation.easeOut(duration: 0.18)
    static let exitEase = Animation.easeOut(duration: 0.38)
    static let deckSpring = Animation.spring(response: 0.42, dampingFraction: 0.88)
}

struct DexterSuggestionCardEntranceModifier: ViewModifier {
    let staggerIndex: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .scaleEffect(isVisible ? 1 : 0.98)
            .onAppear {
                guard !DexterMotionPreferences.shouldReduceMotion else {
                    isVisible = true
                    return
                }
                let delay = DexterSuggestionMotion.staggerStep * Double(min(staggerIndex, 12))
                withAnimation(DexterSuggestionMotion.entranceSpring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func dexterSuggestionCardEntrance(staggerIndex: Int) -> some View {
        modifier(DexterSuggestionCardEntranceModifier(staggerIndex: staggerIndex))
    }
}

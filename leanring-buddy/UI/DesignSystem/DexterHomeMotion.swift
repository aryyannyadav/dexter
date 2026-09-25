//
//  DexterHomeMotion.swift
//  leanring-buddy
//

import SwiftUI

/// Staggered entrance for Home dashboard sections (respects Reduce Motion).
struct DexterHomeStaggeredEntrance: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .onAppear {
                guard !DexterMotionPreferences.shouldReduceMotion else {
                    isVisible = true
                    return
                }
                let delay = 0.06 * Double(min(index, 8))
                withAnimation(DexterAnimation.standardSpring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func dexterHomeStaggeredEntrance(index: Int) -> some View {
        modifier(DexterHomeStaggeredEntrance(index: index))
    }
}

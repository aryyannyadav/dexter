//
//  DexterChatView.swift
//  leanring-buddy
//

import SwiftUI

/// Legacy entry point — Home chat pane is the canonical main conversation UI.
struct DexterChatView: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var composerText: String

    var body: some View {
        DexterHomeChatPane(companionManager: companionManager, composerText: $composerText)
    }
}

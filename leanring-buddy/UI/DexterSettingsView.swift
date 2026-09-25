//
//  DexterSettingsView.swift
//  leanring-buddy
//
//  Legacy entry — opens the dedicated settings window shell.
//

import SwiftUI

struct DexterSettingsView: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        Color.clear
            .onAppear {
                NotificationCenter.default.post(name: .dexterOpenMainWindowSettings, object: nil)
            }
    }
}

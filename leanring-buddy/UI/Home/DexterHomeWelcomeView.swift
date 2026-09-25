//
//  DexterHomeWelcomeView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeWelcomeView: View {
    @ObservedObject var companionManager: CompanionManager
    let onPromptSelected: (String) -> Void

    var body: some View {
        DexterHomeDashboardView(companionManager: companionManager)
    }
}

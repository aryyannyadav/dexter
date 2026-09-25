//
//  DexterMainWindowView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterMainWindowView: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        DexterHomeView(companionManager: companionManager)
    }
}

//
//  CompanionPanelView.swift
//  leanring-buddy
//

import SwiftUI

struct CompanionPanelView: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        DexterMenuBarPanelContent(companionManager: companionManager)
    }
}

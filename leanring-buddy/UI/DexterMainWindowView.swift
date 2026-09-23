//
//  DexterMainWindowView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterMainWindowView: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var destination: DexterMainWindowDestination = .chat
    @State private var composerText: String = ""

    var body: some View {
        GeometryReader { geometry in
            let isSidebarCollapsed = geometry.size.width < 720

            HStack(spacing: 0) {
                DexterSidebar(
                    companionManager: companionManager,
                    selection: $destination,
                    isCollapsed: isSidebarCollapsed
                )

                Group {
                    switch destination {
                    case .chat:
                        DexterChatView(companionManager: companionManager, composerText: $composerText)
                    case .settings:
                        DexterSettingsView(companionManager: companionManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DS.Colors.background)
        .onReceive(NotificationCenter.default.publisher(for: .dexterOpenMainWindowSettings)) { _ in
            destination = .settings
        }
        .onAppear {
            destination = companionManager.pendingMainWindowDestination
            companionManager.pendingMainWindowDestination = .chat
        }
    }
}

//
//  DexterSettingsWindowManager.swift
//  leanring-buddy
//

import AppKit
import SwiftUI

@MainActor
final class DexterSettingsWindowManager {
    private weak var companionManager: CompanionManager?
    private weak var settingsRouter: DexterSettingsRouter?

    func install(companionManager: CompanionManager, settingsRouter: DexterSettingsRouter) {
        self.companionManager = companionManager
        self.settingsRouter = settingsRouter

        NotificationCenter.default.addObserver(
            forName: .dexterOpenMainWindowSettings,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let page = notification.object as? DexterSettingsPage {
                    self?.openSettingsWindow(initialPage: page)
                } else {
                    self?.openSettingsWindow()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .dexterOpenVoiceSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openSettingsWindow(initialPage: .voice)
            }
        }
    }

    func openSettingsWindow(initialPage: DexterSettingsPage = .general) {
        settingsRouter?.open(page: initialPage)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

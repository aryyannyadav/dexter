//
//  DexterMainWindowManager.swift
//  leanring-buddy
//

import AppKit
import SwiftUI

extension Notification.Name {
    static let dexterOpenMainWindow = Notification.Name("dexterOpenMainWindow")
    static let dexterOpenMainWindowSettings = Notification.Name("dexterOpenMainWindowSettings")
}

@MainActor
final class DexterMainWindowManager {
    private var mainWindow: NSWindow?
    private weak var companionManager: CompanionManager?

    func install(companionManager: CompanionManager) {
        self.companionManager = companionManager

        NotificationCenter.default.addObserver(
            forName: .dexterOpenMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openMainWindow()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .dexterOpenMainWindowSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openMainWindow(showSettings: true)
            }
        }
    }

    func openMainWindow(showSettings: Bool = false) {
        guard let companionManager else { return }

        if showSettings {
            companionManager.pendingMainWindowDestination = .settings
        }

        if mainWindow == nil {
            let rootView = DexterMainWindowView(companionManager: companionManager)
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Dexter"
            window.setContentSize(NSSize(width: 980, height: 660))
            window.minSize = NSSize(width: 640, height: 480)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(DS.Colors.background)
            mainWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }
}

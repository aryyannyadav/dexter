//
//  DexterMainWindowManager.swift
//  leanring-buddy
//

import AppKit
import SwiftUI

extension Notification.Name {
    static let dexterOpenMainWindow = Notification.Name("dexterOpenMainWindow")
    static let dexterOpenMainWindowSettings = Notification.Name("dexterOpenMainWindowSettings")
    static let dexterHomeApplyWindowLayoutMode = Notification.Name("dexterHomeApplyWindowLayoutMode")
    static let dexterHomeFocusChat = Notification.Name("dexterHomeFocusChat")
    static let dexterOpenVoiceSettings = Notification.Name("dexterOpenVoiceSettings")
}

@MainActor
final class DexterMainWindowManager {
    private var mainWindow: NSWindow?
    private weak var companionManager: CompanionManager?
    private let homeWindowFrameObserver = DexterHomeWindowFrameObserver()

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
            forName: .dexterHomeApplyWindowLayoutMode,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let mode = notification.object as? DexterHomeWindowLayoutMode else { return }
                self?.applyHomeWindowLayoutMode(mode)
            }
        }
    }

    func openMainWindow(showSettings: Bool = false) {
        guard let companionManager else { return }

        if showSettings {
            NotificationCenter.default.post(name: .dexterOpenMainWindowSettings, object: nil)
            return
        }

        if mainWindow == nil {
            let rootView = DexterMainWindowView(companionManager: companionManager)
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Dexter"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(DexterColors.background)
            window.delegate = homeWindowFrameObserver

            let layoutMode = DexterHomeWindowPreferences.layoutMode
            window.minSize = layoutMode.minimumSize

            if let savedFrame = DexterHomeWindowPreferences.savedFrame() {
                window.setFrame(savedFrame, display: true)
            } else {
                window.setContentSize(
                    NSSize(
                        width: max(layoutMode.defaultContentSize.width, 980),
                        height: max(layoutMode.defaultContentSize.height, 640)
                    )
                )
                window.center()
            }

            mainWindow = window
        }

        guard let window = mainWindow else { return }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// Dock click, reopen, and explicit "open Dexter" should land on Home.
    func focusHomeWindow() {
        openMainWindow()
    }

    private func applyHomeWindowLayoutMode(_ mode: DexterHomeWindowLayoutMode) {
        guard let window = mainWindow else { return }
        DexterHomeWindowPreferences.applyLayoutMode(mode, to: window)
    }
}

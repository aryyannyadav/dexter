//
//  DexterAgentHUDPanelManager.swift
//  leanring-buddy
//

import AppKit
import Combine
import SwiftUI

private final class DexterAgentHUDKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { false }
}

@MainActor
final class DexterAgentHUDPanelManager {
    private let companionManager: CompanionManager
    private var panel: NSPanel?
    private var visibilityTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
    }

    func install() {
        companionManager.dexterAgentHUDController.install(companionManager: companionManager)

        companionManager.dexterAgentHUDController.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncPanelVisibility()
            }
            .store(in: &cancellables)

        companionManager.dexterRuntimeUIStateStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncPanelVisibility()
            }
            .store(in: &cancellables)

        companionManager.$actionConfirmationPresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncPanelVisibility()
            }
            .store(in: &cancellables)

        visibilityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncPanelVisibility()
            }
        }
    }

    private func syncPanelVisibility() {
        guard DexterAgentSettingsStore.shared.showUpdatesBesideCursor else {
            hidePanel()
            return
        }

        let presentation = companionManager.dexterAgentHUDController.presentation
        if DexterAgentHUDResolver.shouldShowHUD(presentation: presentation) {
            showPanel()
        } else {
            hidePanel()
        }
    }

    private func showPanel() {
        if panel == nil {
            createPanel()
        }
        positionPanel()
        panel?.orderFrontRegardless()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let rootView = DexterAgentHUDView(
            companionManager: companionManager,
            hudController: companionManager.dexterAgentHUDController
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 220)

        let hudPanel = DexterAgentHUDKeyablePanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        hudPanel.isFloatingPanel = true
        hudPanel.level = .floating
        hudPanel.isOpaque = false
        hudPanel.backgroundColor = .clear
        hudPanel.hasShadow = false
        hudPanel.hidesOnDeactivate = false
        hudPanel.isExcludedFromWindowsMenu = true
        hudPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hudPanel.contentView = hostingView
        panel = hudPanel
    }

    private func positionPanel() {
        guard let panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let margin: CGFloat = 20
        let size = panel.frame.size
        let originX = screen.visibleFrame.maxX - size.width - margin
        let originY = screen.visibleFrame.minY + margin
        panel.setFrameOrigin(CGPoint(x: originX, y: originY))
    }
}

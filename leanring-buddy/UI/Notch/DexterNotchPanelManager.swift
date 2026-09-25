//
//  DexterNotchPanelManager.swift
//  leanring-buddy
//
//  Ambient notch companion — borderless NSPanel anchored to the top center
//  of the built-in display. Separate from the full-screen cursor overlay.
//

import AppKit
import Combine
import SwiftUI

private final class DexterNotchKeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class DexterNotchPanelManager: NSObject {
    private let companionManager: CompanionManager
    private let chromeController = DexterNotchChromeController()
    private let attentionStore = DexterNotchAttentionStore()
    private let recommendationStore = DexterNotchRecommendationStore()
    private let ambientStore = DexterNotchAmbientStore()

    private var panel: NSPanel?
    private var escapeKeyMonitor: Any?
    private var screenParametersObserver: NSObjectProtocol?
    private var chromeModeCancellable: AnyCancellable?
    private var recommendationCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        super.init()
    }

    func install() {
        attentionStore.chromeController = chromeController
        attentionStore.install(companionManager: companionManager)
        recommendationStore.install(companionManager: companionManager)
        ambientStore.chromeController = chromeController
        ambientStore.install(companionManager: companionManager, recommendationStore: recommendationStore)
        createPanelIfNeeded()
        repositionPanel(animated: false)
        panel?.orderFrontRegardless()

        chromeModeCancellable = chromeController.$chromeMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionPanel(animated: true)
                self?.updateKeyMonitor()
            }

        recommendationCancellable = recommendationStore.$currentRecommendation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionPanel(animated: true)
            }

        ambientStore.$resolvedState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.repositionPanel(animated: true)
            }
            .store(in: &cancellables)

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.repositionPanel(animated: false)
            }
        }
    }

    func show() {
        createPanelIfNeeded()
        repositionPanel(animated: false)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        removeEscapeKeyMonitor()
    }

    private func createPanelIfNeeded() {
        guard panel == nil else { return }

        let rootView = DexterNotchPresenceView(
            companionManager: companionManager,
            chromeController: chromeController,
            attentionStore: attentionStore,
            recommendationStore: recommendationStore,
            ambientStore: ambientStore
        )

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: DexterMetrics.notchExpandedHeight)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        let notchPanel = DexterNotchKeyablePanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        notchPanel.isFloatingPanel = true
        notchPanel.level = .statusBar
        notchPanel.isOpaque = false
        notchPanel.backgroundColor = .clear
        notchPanel.hasShadow = false
        notchPanel.hidesOnDeactivate = false
        notchPanel.isExcludedFromWindowsMenu = true
        notchPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        notchPanel.isMovableByWindowBackground = false
        notchPanel.titleVisibility = .hidden
        notchPanel.titlebarAppearsTransparent = true
        notchPanel.contentView = hostingView
        panel = notchPanel
    }

    private func repositionPanel(animated: Bool) {
        guard let panel else { return }
        let screen = DexterNotchGeometry.preferredDisplayScreen()
        let targetSize = chromeController.chromeMode.contentSize(
            ambientState: ambientStore.resolvedState.ambientState,
            recommendation: recommendationStore.currentRecommendation
        )
        let targetFrame = DexterNotchGeometry.centeredFrame(size: targetSize, on: screen)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = DexterAnimation.standard
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }

        if let hostingView = panel.contentView as? NSHostingView<DexterNotchPresenceView> {
            hostingView.frame = NSRect(origin: .zero, size: targetSize)
        } else if let hostingView = panel.contentView {
            hostingView.frame = NSRect(origin: .zero, size: targetSize)
        }
    }

    private func updateKeyMonitor() {
        if chromeController.chromeMode == .expanded {
            installEscapeKeyMonitor()
            panel?.makeKey()
        } else {
            removeEscapeKeyMonitor()
        }
    }

    private func installEscapeKeyMonitor() {
        guard escapeKeyMonitor == nil else { return }
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.chromeController.collapseFromEscape()
            self?.attentionStore.clearAttentionForUserInteraction()
            return nil
        }
    }

    private func removeEscapeKeyMonitor() {
        if let escapeKeyMonitor {
            NSEvent.removeMonitor(escapeKeyMonitor)
            self.escapeKeyMonitor = nil
        }
    }
}

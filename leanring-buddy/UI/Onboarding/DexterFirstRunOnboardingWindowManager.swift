//
//  DexterFirstRunOnboardingWindowManager.swift
//  leanring-buddy
//

import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let dexterFirstRunOnboardingDidFinish = Notification.Name("dexterFirstRunOnboardingDidFinish")
    static let dexterPresentFirstRunOnboarding = Notification.Name("dexterPresentFirstRunOnboarding")
}

@MainActor
final class DexterFirstRunOnboardingWindowManager: NSObject, NSWindowDelegate {
    private var onboardingWindow: NSWindow?
    private weak var companionManager: CompanionManager?
    private var stepObservationCancellable: AnyCancellable?

    func install(companionManager: CompanionManager) {
        self.companionManager = companionManager

        NotificationCenter.default.addObserver(
            forName: .dexterPresentFirstRunOnboarding,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                let replay = (notification.userInfo?["replay"] as? Bool) ?? false
                self?.presentFirstRunOnboarding(replay: replay)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .dexterFirstRunOnboardingDidFinish,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closeOnboardingWindow()
            }
        }
    }

    func presentFirstRunOnboarding(replay: Bool = false) {
        guard let companionManager else { return }

        if replay {
            companionManager.firstRunOnboardingStore.restartForReplay()
        } else {
            DexterAnalytics.trackOnboardingStarted()
            DexterAnalytics.trackFirstRunOnboardingStepViewed(step: companionManager.firstRunOnboardingStore.currentStep)
        }

        if onboardingWindow == nil {
            let rootView = DexterFirstRunOnboardingView(companionManager: companionManager)
            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Welcome to Dexter"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(DexterColors.background)
            window.delegate = self
            window.setContentSize(NSSize(width: 760, height: 640))
            window.minSize = NSSize(width: 640, height: 520)
            window.center()
            onboardingWindow = window

            stepObservationCancellable = companionManager.firstRunOnboardingStore.$currentStep
                .receive(on: DispatchQueue.main)
                .sink { [weak self] step in
                    self?.applyWindowFocusPolicy(for: step)
                }
        }

        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
        applyWindowFocusPolicy(for: companionManager.firstRunOnboardingStore.currentStep)
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
        stepObservationCancellable = nil
    }

    private func applyWindowFocusPolicy(for step: DexterFirstRunOnboardingStep) {
        guard let window = onboardingWindow else { return }
        if step.usesInteractiveDesktop {
            window.orderFrontRegardless()
        } else {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let companionManager else { return true }
        if companionManager.hasCompletedOnboarding {
            return true
        }
        companionManager.skipFirstRunProductOnboardingAndOpenHome()
        return true
    }
}

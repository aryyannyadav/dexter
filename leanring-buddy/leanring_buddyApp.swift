//
//  leanring_buddyApp.swift
//  leanring-buddy
//
//  Dexter macOS app: Dock + Home window, with menu bar companion access.
//

import ServiceManagement
import SwiftUI
import Sparkle

@main
struct leanring_buddyApp: App {
    @NSApplicationDelegateAdaptor(CompanionAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            if let companionManager = appDelegate.companionManagerForSettings {
                DexterSettingsShell(
                    companionManager: companionManager,
                    router: appDelegate.settingsRouter
                )
            } else {
                Text("Dexter Settings")
                    .frame(width: 320, height: 120)
            }
        }
    }
}

/// Manages the companion lifecycle: creates the menu bar panel and starts
/// the companion voice pipeline on launch.
@MainActor
final class CompanionAppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: CompanionAppDelegate?

    private var menuBarPanelManager: MenuBarPanelManager?
    let companionManager = CompanionManager()
    let settingsRouter = DexterSettingsRouter()
    var companionManagerForSettings: CompanionManager? { companionManager }
    private let dexterMainWindowManager = DexterMainWindowManager()
    private let dexterSettingsWindowManager = DexterSettingsWindowManager()
    private let dexterFirstRunOnboardingWindowManager = DexterFirstRunOnboardingWindowManager()
    private var dexterNotchPanelManager: DexterNotchPanelManager?
    private var dexterAgentHUDPanelManager: DexterAgentHUDPanelManager?
    private var sparkleUpdaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CompanionAppDelegate.shared = self
        print("🎯 Dexter: Starting...")
        print("🎯 Dexter: Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")

        NSApp.setActivationPolicy(.regular)

        UserDefaults.standard.register(defaults: [
            "NSInitialToolTipDelay": 0,
            "dexterDevelopmentContextInspectorEnabled": false
        ])

        DexterAnalytics.configure()
        DexterAnalytics.trackAppOpened()

        dexterMainWindowManager.install(companionManager: companionManager)
        dexterSettingsWindowManager.install(
            companionManager: companionManager,
            settingsRouter: settingsRouter
        )
        dexterFirstRunOnboardingWindowManager.install(companionManager: companionManager)
        menuBarPanelManager = MenuBarPanelManager(companionManager: companionManager)
        dexterNotchPanelManager = DexterNotchPanelManager(companionManager: companionManager)
        dexterNotchPanelManager?.install()
        dexterAgentHUDPanelManager = DexterAgentHUDPanelManager(companionManager: companionManager)
        dexterAgentHUDPanelManager?.install()
        companionManager.installUniversalCommand(settingsRouter: settingsRouter)
        companionManager.start()
        if !companionManager.hasCompletedOnboarding {
            companionManager.firstRunOnboardingStore.beginIfNeeded()
            dexterFirstRunOnboardingWindowManager.presentFirstRunOnboarding()
        } else {
            if DexterGeneralSettingsStore.shared.openHomeWhenDexterLaunches {
                dexterMainWindowManager.openMainWindow()
            }
            if !companionManager.allPermissionsGranted {
                menuBarPanelManager?.showPanelOnLaunch()
            }
        }
        // startSparkleUpdater()
    }

    func applicationWillTerminate(_ notification: Notification) {
        companionManager.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        dexterMainWindowManager.focusHomeWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startSparkleUpdater() {
        let updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.sparkleUpdaterController = updaterController

        do {
            try updaterController.updater.start()
        } catch {
            print("⚠️ Dexter: Sparkle updater failed to start: \(error)")
        }
    }
}

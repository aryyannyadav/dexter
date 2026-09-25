//
//  DexterGeneralSettingsPage.swift
//  leanring-buddy
//

import ServiceManagement
import SwiftUI

struct DexterGeneralSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @StateObject private var generalSettings = DexterGeneralSettingsStore.shared

    var body: some View {
        DexterSettingsPageContainer(
            title: "General",
            subtitle: "Startup and companion visibility."
        ) {
            DexterSettingsSection(title: "Startup") {
                DexterSettingsToggleRow(
                    title: "Launch at login",
                    subtitle: "Open Dexter automatically when you sign in to this Mac.",
                    isOn: Binding(
                        get: { isLoginItemEnabled },
                        set: { setLoginItemEnabled($0) }
                    )
                )
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "Open Home when Dexter launches",
                    subtitle: "Show the Dexter Home window after onboarding completes.",
                    isOn: $generalSettings.openHomeWhenDexterLaunches
                )
            }

            DexterSettingsSection(title: "Companion") {
                DexterSettingsInfoRow(title: "Menu bar item", value: "On")
                DexterSettingsDivider()
                DexterSettingsInfoRow(title: "Dock", value: "On")
                Text("Dexter runs as a regular macOS app with a menu bar companion and Dock icon.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.top, 4)
            }
        }
    }

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func setLoginItemEnabled(_ isEnabled: Bool) {
        let loginItemService = SMAppService.mainApp
        do {
            if isEnabled {
                try loginItemService.register()
            } else {
                try loginItemService.unregister()
            }
        } catch {
            print("⚠️ Login item update failed: \(error.localizedDescription)")
        }
    }
}

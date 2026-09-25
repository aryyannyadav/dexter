//
//  DexterComputerControlSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterComputerControlSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var isComputerControlEnabled = DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled

    private var computerControlAvailabilityLabel: String {
        let capability = companionManager.dexterProductCapabilities.first { $0.capabilityID == .computerControl }
        switch capability?.availability {
        case .available:
            return "Available"
        case .requiresPermission:
            return "Requires permission"
        case .unavailable, .unsupported:
            return "Unavailable"
        case .requiresConnection:
            return "Unavailable"
        case .none:
            return companionManager.openClawGatewayHealthMonitor.connectionState.isConnected ? "Available" : "Unavailable"
        }
    }

    var body: some View {
        DexterSettingsPageContainer(
            title: "Computer Control",
            subtitle: "Permissions and behavior for verified computer actions."
        ) {
            DexterSettingsSection(title: "Status") {
                DexterSettingsInfoRow(title: "Computer control", value: computerControlAvailabilityLabel)
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Computer runtime",
                    value: companionManager.openClawGatewayHealthMonitor.connectionState.isConnected
                        ? "Connected"
                        : "Disconnected"
                )
            }

            DexterSettingsSection(title: "Behavior") {
                DexterSettingsToggleRow(
                    title: "Allow computer use",
                    subtitle: "When off, Dexter explains and plans but does not execute actions.",
                    isOn: Binding(
                        get: { isComputerControlEnabled },
                        set: { newValue in
                            isComputerControlEnabled = newValue
                            DexterObserveOnlyPolicy.setAutonomousComputerControlEnabled(newValue)
                        }
                    )
                )
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "Auto-approve low-risk actions",
                    subtitle: "Skip confirmation for policy-approved low-risk actions.",
                    isOn: Binding(
                        get: { companionManager.autoApproveLowRiskActions },
                        set: { companionManager.autoApproveLowRiskActions = $0 }
                    )
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Verify actions",
                    value: "Always on"
                )
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "Show action progress",
                    subtitle: "Display the Agent HUD beside the cursor during computer use.",
                    isOn: Binding(
                        get: { DexterAgentSettingsStore.shared.showUpdatesBesideCursor },
                        set: { DexterAgentSettingsStore.shared.showUpdatesBesideCursor = $0 }
                    )
                )
            }

            DexterSettingsSection(title: "Runtime") {
                DexterOpenClawRuntimeStatusSection(
                    healthMonitor: companionManager.openClawGatewayHealthMonitor,
                    onRefresh: { companionManager.refreshOpenClawGatewayConnection() },
                    showsTechnicalDetails: DexterDeveloperModeSettings.isDeveloperModeEnabled
                )
            }
        }
    }
}

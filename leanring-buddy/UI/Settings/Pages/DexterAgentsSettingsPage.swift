//
//  DexterAgentsSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterAgentsSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @StateObject private var agentSettings = DexterAgentSettingsStore.shared
    @State private var isComputerControlEnabled = DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled

    var body: some View {
        DexterSettingsPageContainer(
            title: "Agents",
            subtitle: "Autonomy and announcements for Dexter computer actions."
        ) {
            DexterSettingsSection(title: "Autonomy") {
                DexterSettingsToggleRow(
                    title: "Auto-approve low-risk actions",
                    subtitle: "Automatically approve low-risk actions when policy allows.",
                    isOn: Binding(
                        get: { companionManager.autoApproveLowRiskActions },
                        set: { companionManager.autoApproveLowRiskActions = $0 }
                    )
                )
                DexterSettingsDivider()
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
                    title: "Suggest agent tasks",
                    subtitle: "Surface grounded suggestions on Home when context supports them.",
                    isOn: $agentSettings.suggestAgentTasks
                )
            }

            DexterOpenClawRuntimeStatusSection(
                healthMonitor: companionManager.openClawGatewayHealthMonitor,
                onRefresh: { companionManager.refreshOpenClawGatewayConnection() }
            )

            DexterSettingsSection(title: "Announcements") {
                DexterSettingsToggleRow(
                    title: "Speak when an action starts or finishes",
                    subtitle: "Short spoken status when Dexter runs verified computer actions.",
                    isOn: $agentSettings.speakWhenAgentStartsOrFinishes
                )
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "Show updates beside the cursor",
                    subtitle: "Display the Agent HUD during computer use.",
                    isOn: $agentSettings.showUpdatesBesideCursor
                )
            }
        }
    }
}

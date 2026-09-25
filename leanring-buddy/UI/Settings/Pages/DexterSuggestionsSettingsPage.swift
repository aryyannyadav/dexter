//
//  DexterSuggestionsSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSuggestionsSettingsPage: View {
    @StateObject private var agentSettings = DexterAgentSettingsStore.shared

    var body: some View {
        DexterSettingsPageContainer(
            title: "Suggestions",
            subtitle: "Grounded suggestions from your current Dexter context."
        ) {
            DexterSettingsSection(title: "Suggestions") {
                DexterSettingsToggleRow(
                    title: "Show suggestions",
                    subtitle: "Surface contextual suggestions on Home and in the notch when Dexter has grounded context.",
                    isOn: $agentSettings.suggestAgentTasks
                )
            }

            DexterSettingsSection(title: "Surfaces") {
                VStack(alignment: .leading, spacing: DexterSpacing.sm) {
                    Text("Home, the notch, and the sidebar Suggestions thread all use the same grounded suggestion cards.")
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Turning suggestions off hides them in every surface.")
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DexterPastelColors.lavender.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

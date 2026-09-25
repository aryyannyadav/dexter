//
//  DexterPrivacySettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterPrivacySettingsPage: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        DexterSettingsPageContainer(
            title: "Privacy",
            subtitle: "What Dexter can access on your Mac."
        ) {
            DexterSettingsSection(title: "Access") {
                privacyRow(
                    title: "Screen",
                    detail: "Captured on demand when a request needs visual context — not continuous recording.",
                    status: companionManager.hasScreenRecordingPermission ? "Allowed" : "Requires permission"
                )
                DexterSettingsDivider()
                privacyRow(
                    title: "Microphone",
                    detail: "Used for push-to-talk voice input when you hold the shortcut.",
                    status: companionManager.hasMicrophonePermission ? "Allowed" : "Requires permission"
                )
                DexterSettingsDivider()
                privacyRow(
                    title: "Computer control",
                    detail: "Verified actions through OpenClaw and local runtimes when you allow them.",
                    status: DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled ? "Enabled" : "Disabled"
                )
                DexterSettingsDivider()
                privacyRow(
                    title: "Files",
                    detail: "Limited to approved folders when Dexter runs file tools.",
                    status: "Policy-gated"
                )
                DexterSettingsDivider()
                privacyRow(
                    title: "Integrations",
                    detail: "Only connectors you configure or authorize.",
                    status: "\(companionManager.dexterIntegrationService.integrations.filter { $0.connectionState == .connected }.count) connected"
                )
                DexterSettingsDivider()
                privacyRow(
                    title: "Memory",
                    detail: "Saved only when you ask Dexter to remember something.",
                    status: "\(companionManager.dexterPersistentMemoryEntries.count) saved"
                )
            }
        }
    }

    private func privacyRow(title: String, detail: String, status: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(DexterSettingsTypography.rowTitle())
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text(status)
                    .font(DexterSettingsTypography.secondaryValue())
                    .foregroundColor(DS.Colors.textTertiary)
            }
            Text(detail)
                .font(DexterSettingsTypography.rowSubtitle())
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

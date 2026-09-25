//
//  DexterOpenClawRuntimeStatusSection.swift
//  leanring-buddy
//

import SwiftUI

struct DexterOpenClawRuntimeStatusSection: View {
    @ObservedObject var healthMonitor: OpenClawGatewayHealthMonitor
    let onRefresh: () -> Void
    var showsTechnicalDetails: Bool = false

    private var capabilityRows: [DexterOpenClawSettingsCapabilityRow] {
        DexterOpenClawRuntimeCapabilityRegistry.settingsCapabilityRows(
            discoveryReport: healthMonitor.capabilityDiscoveryReport,
            nodeSnapshot: healthMonitor.preferredNodeSnapshot
        )
    }

    var body: some View {
        DexterSettingsSection(title: showsTechnicalDetails ? "OpenClaw" : "Runtime") {
            DexterSettingsInfoRow(
                title: "Status",
                value: healthMonitor.connectionState.isConnected ? "Connected" : healthMonitor.statusLine
            )

            if showsTechnicalDetails {
                if let version = healthMonitor.detectedOpenClawVersion {
                    DexterSettingsDivider()
                    DexterSettingsInfoRow(title: "Version", value: version)
                }
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Gateway",
                    value: DexterOpenClawRuntimeCapabilityRegistry.gatewayConnectionLabel(
                        connectionState: healthMonitor.connectionState
                    )
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Node",
                    value: DexterOpenClawRuntimeCapabilityRegistry.nodeConnectionLabel(
                        nodeSnapshot: healthMonitor.preferredNodeSnapshot
                    )
                )

                if !capabilityRows.isEmpty {
                    DexterSettingsDivider()
                    ForEach(Array(capabilityRows.enumerated()), id: \.element.id) { index, capabilityRow in
                        if index > 0 {
                            DexterSettingsDivider()
                        }
                        DexterOpenClawCapabilitySettingsRow(capabilityRow: capabilityRow)
                    }
                }
            }

            DexterSettingsSecondaryButton(
                title: showsTechnicalDetails ? "Refresh capabilities" : "Reconnect"
            ) {
                onRefresh()
            }
            .padding(.top, 6)
        }
    }
}

private struct DexterOpenClawCapabilitySettingsRow: View {
    let capabilityRow: DexterOpenClawSettingsCapabilityRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(capabilityRow.title)
                    .font(DexterSettingsTypography.rowTitle())
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text(capabilityRow.statusLabel)
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(capabilityRow.isAvailable ? DexterPastelColors.mint : DS.Colors.textTertiary)
            }
            if let detail = capabilityRow.detail {
                Text(detail)
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

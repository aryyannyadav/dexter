//
//  DexterPermissionsSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterPermissionsSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        DexterSettingsPageContainer(
            title: "Permissions",
            subtitle: "macOS permissions Dexter needs for voice, screen context, and computer control."
        ) {
            DexterSettingsSection(title: "Permission center") {
                permissionRow(
                    title: "Microphone",
                    status: permissionLabel(isGranted: companionManager.hasMicrophonePermission),
                    opensSettings: !companionManager.hasMicrophonePermission
                )
                DexterSettingsDivider()
                permissionRow(
                    title: "Screen Recording",
                    status: permissionLabel(isGranted: companionManager.hasScreenRecordingPermission),
                    opensSettings: !companionManager.hasScreenRecordingPermission
                )
                DexterSettingsDivider()
                permissionRow(
                    title: "Accessibility",
                    status: permissionLabel(isGranted: companionManager.hasAccessibilityPermission),
                    opensSettings: !companionManager.hasAccessibilityPermission
                )
                DexterSettingsDivider()
                permissionRow(
                    title: "Screen content",
                    status: companionManager.hasScreenContentPermission ? "Allowed" : "Not requested",
                    opensSettings: false
                )
                DexterSettingsDivider()
                permissionRow(
                    title: "Automation",
                    status: companionManager.hasAccessibilityPermission ? "Available via Accessibility" : "Requires Accessibility",
                    opensSettings: !companionManager.hasAccessibilityPermission
                )
            }

            DexterSettingsSecondaryButton(title: "Refresh permission state") {
                companionManager.refreshAllPermissions()
            }
            .padding(.top, 4)
        }
    }

    private func permissionLabel(isGranted: Bool) -> String {
        isGranted ? "Allowed" : "Requires permission"
    }

    @ViewBuilder
    private func permissionRow(title: String, status: String, opensSettings: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(DexterSettingsTypography.rowTitle())
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text(status)
                    .font(DexterSettingsTypography.secondaryValue())
                    .foregroundColor(DS.Colors.textTertiary)
            }
            if opensSettings {
                DexterSettingsSecondaryButton(title: "Open System Settings") {
                    openSystemSettings(for: title)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func openSystemSettings(for permissionTitle: String) {
        switch permissionTitle {
        case "Microphone":
            companionManager.buddyDictationManager.openRelevantPrivacySettings()
        case "Screen Recording":
            WindowPositionManager.requestScreenRecordingPermission()
        case "Accessibility":
            WindowPositionManager.requestAccessibilityPermission()
        default:
            break
        }
    }
}

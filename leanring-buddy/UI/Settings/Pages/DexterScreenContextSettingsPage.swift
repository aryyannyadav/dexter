//
//  DexterScreenContextSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterScreenContextSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @StateObject private var screenContextSettings = DexterScreenContextSettingsStore.shared

    var body: some View {
        DexterSettingsPageContainer(
            title: "Screen Context",
            subtitle: "Control when Dexter may use screen and pointer context."
        ) {
            DexterSettingsSection(title: "Capture") {
                DexterSettingsToggleRow(
                    title: "Screen context",
                    subtitle: "Allow Dexter to capture screen images when a request needs visual context.",
                    isOn: $screenContextSettings.isScreenContextEnabled
                )
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "Pointer context",
                    subtitle: "Include what is under your cursor for point-and-ask and guidance.",
                    isOn: $screenContextSettings.isPointerContextEnabled
                )
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "OCR at pointer",
                    subtitle: "Read nearby text when accessibility data is not enough.",
                    isOn: $screenContextSettings.isOCREnabled
                )
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "Visual reasoning",
                    subtitle: "Run local vision hints for appearance questions at the pointer.",
                    isOn: $screenContextSettings.isVisualReasoningEnabled
                )
            }

            DexterSettingsSection(title: "Privacy") {
                Text("Dexter only captures screen context when needed for an interaction — not continuous recording.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                DexterSettingsInfoRow(
                    title: "Screen Recording permission",
                    value: companionManager.hasScreenRecordingPermission ? "Allowed" : "Requires permission"
                )
            }
        }
    }
}

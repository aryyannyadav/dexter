//
//  DexterShortcutsSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterShortcutsSettingsPage: View {
    @StateObject private var shortcutSettings = DexterShortcutSettingsStore.shared
    @State private var isPushToTalkPickerPresented = false

    var body: some View {
        DexterSettingsPageContainer(
            title: "Shortcuts",
            subtitle: "Global keyboard shortcuts for voice and point-and-ask."
        ) {
            DexterSettingsSection(title: nil) {
                DexterShortcutRow(
                    title: "Push to talk",
                    subtitle: "Hold to talk. Release to send.",
                    shortcutLabel: shortcutSettings.pushToTalkShortcutOption.displayText,
                    canChange: true,
                    onChange: { isPushToTalkPickerPresented = true }
                )
                DexterSettingsDivider()
                DexterShortcutRow(
                    title: "Point and ask",
                    subtitle: "Capture the pointer context and open Dexter.",
                    shortcutLabel: DexterShortcutSettingsDisplay.pointInvokeLabel,
                    canChange: false,
                    onChange: {}
                )
                DexterSettingsDivider()
                DexterShortcutRow(
                    title: "Text mode",
                    subtitle: "Open the Dexter Home window and focus the composer.",
                    shortcutLabel: DexterGlobalHomeShortcutMonitor.textModeShortcutDisplayText,
                    canChange: false,
                    onChange: {}
                )
                DexterSettingsDivider()
                DexterShortcutRow(
                    title: "Dictate",
                    subtitle: "Microphone button in the menu bar panel composer.",
                    shortcutLabel: "Panel button",
                    canChange: false,
                    onChange: {}
                )
            }

            DexterSettingsSecondaryButton(title: "Reset defaults") {
                shortcutSettings.resetToDefaults()
            }
        }
        .sheet(isPresented: $isPushToTalkPickerPresented) {
            DexterPushToTalkShortcutPickerSheet(
                selectedOption: shortcutSettings.pushToTalkShortcutOption,
                onSelectOption: { option in
                    shortcutSettings.pushToTalkShortcutOption = option
                    isPushToTalkPickerPresented = false
                }
            )
        }
    }
}

struct DexterPushToTalkShortcutPickerSheet: View {
    let selectedOption: BuddyPushToTalkShortcut.ShortcutOption
    let onSelectOption: (BuddyPushToTalkShortcut.ShortcutOption) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [BuddyPushToTalkShortcut.ShortcutOption] = [
        .controlOption,
        .shiftFunction,
        .shiftControl,
        .controlOptionSpace,
        .shiftControlSpace
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Push-to-talk shortcut")
                .font(.system(size: 18, weight: .semibold))

            Text("Choose a modifier combination Dexter listens for globally while the app is running.")
                .font(DexterSettingsTypography.pageSubtitle())
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(options, id: \.storageKey) { option in
                    let index = options.firstIndex(where: { $0.storageKey == option.storageKey }) ?? 0
                    Button {
                        onSelectOption(option)
                    } label: {
                        HStack {
                            Text(option.displayText)
                                .font(DexterSettingsTypography.rowTitle())
                                .foregroundColor(DS.Colors.textPrimary)
                            Spacer()
                            if option == selectedOption {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DexterIdentity.accent)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    if index < options.count - 1 {
                        DexterSettingsDivider()
                    }
                }
            }

            HStack {
                Spacer()
                DexterSettingsSecondaryButton(title: "Close") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(DexterSettingsColors.contentBackground)
    }
}

struct DexterShortcutRow: View {
    let title: String
    let subtitle: String
    let shortcutLabel: String
    let canChange: Bool
    let onChange: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DexterSettingsTypography.rowTitle())
                    .foregroundColor(DS.Colors.textPrimary)
                Text(subtitle)
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            DexterShortcutChip(label: shortcutLabel)
            DexterSettingsSecondaryButton(title: "Change") {
                onChange()
            }
            .disabled(!canChange)
            .opacity(canChange ? 1 : 0.45)
        }
        .padding(.vertical, 10)
    }
}

struct DexterShortcutChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(DS.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(DexterSettingsColors.searchFieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(DexterSettingsColors.searchFieldBorder, lineWidth: 1)
            )
    }
}

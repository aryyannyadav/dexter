//
//  DexterCursorSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterCursorSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @StateObject private var cursorSettings = DexterCursorSettingsStore.shared

    var body: some View {
        DexterSettingsPageContainer(
            title: "Cursor",
            subtitle: "Companion cursor appearance on screen."
        ) {
            DexterSettingsSection(title: "Cursor style") {
                HStack(spacing: 10) {
                    ForEach(DexterCursorStyleOption.allCases) { option in
                        DexterCursorStyleChoice(
                            style: option,
                            accentColor: cursorSettings.selectedAccentColor.swatchColor,
                            isSelected: cursorSettings.selectedCursorStyle == option,
                            onSelect: { cursorSettings.selectedCursorStyle = option }
                        )
                    }
                }
                .padding(.vertical, 6)
            }

            DexterSettingsSection(title: "Cursor size") {
                Picker("Cursor size", selection: $cursorSettings.cursorSizeOption) {
                    ForEach(DexterCursorSizeOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.vertical, 4)
            }

            DexterSettingsSection(title: "Cursor color (Classic)") {
                Text("Accent color applies to the Classic triangle, listening waveform, and thinking spinner — not SpongeBob or Patrick.")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.bottom, 4)
                HStack(spacing: 10) {
                    ForEach(DexterCursorAccentColorOption.allCases) { option in
                        DexterColorChoice(
                            option: option,
                            isSelected: cursorSettings.selectedAccentColor == option,
                            onSelect: { cursorSettings.selectedAccentColor = option }
                        )
                    }
                }
                .padding(.vertical, 6)
            }

            DexterSettingsSection(title: "Visibility") {
                DexterSettingsToggleRow(
                    title: "Show Dexter cursor overlay",
                    subtitle: nil,
                    isOn: Binding(
                        get: { companionManager.isDexterCursorEnabled },
                        set: { companionManager.setDexterCursorEnabled($0) }
                    )
                )
                DexterSettingsDivider()
                DexterSettingsToggleRow(
                    title: "Dock cursor",
                    subtitle: "Keep the companion anchored near the screen edge when idle.",
                    isOn: $cursorSettings.isDockCursorEnabled
                )
            }
        }
    }
}

struct DexterCursorStyleChoice: View {
    let style: DexterCursorStyleOption
    let accentColor: Color
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DexterSettingsColors.rowHover.opacity(0.35))
                        .frame(width: 56, height: 40)

                    DexterCompanionCursorView(
                        style: style,
                        accentColor: accentColor,
                        rotationDegrees: -35,
                        flightScale: 1.0,
                        showsAccentGlow: false,
                        presentationContext: .settingsPreview
                    )
                    .frame(width: 52, height: 36)
                }
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 2)
                )

                Text(style.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? DexterSettingsColors.rowHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .accessibilityLabel("\(style.displayName) cursor style")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct DexterColorChoice: View {
    let option: DexterCursorAccentColorOption
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(option.swatchColor)
                    .frame(width: 56, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 2)
                    )
                Text(option.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? DexterSettingsColors.rowHover : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .accessibilityLabel("\(option.displayName) cursor color")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

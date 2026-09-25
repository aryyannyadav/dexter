//
//  DexterAppearanceSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterAppearanceSettingsPage: View {
    @StateObject private var appearanceSettings = DexterAppearanceSettingsStore.shared

    var body: some View {
        DexterSettingsPageContainer(
            title: "Appearance",
            subtitle: "Theme and accent highlights across Dexter."
        ) {
            DexterSettingsSection(title: "Theme") {
                Picker("Theme", selection: $appearanceSettings.appearanceMode) {
                    ForEach(DexterAppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Light mode is not available yet. System follows your Mac appearance when supported.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.top, 4)
            }

            DexterSettingsSection(title: "Accent color") {
                Text("Used sparingly for buttons, selection, and highlights — not the full interface.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.bottom, 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                    ForEach(DexterProductAccentOption.allCases) { option in
                        DexterProductAccentChoice(
                            option: option,
                            isSelected: appearanceSettings.selectedProductAccent == option,
                            onSelect: { appearanceSettings.selectedProductAccent = option }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct DexterProductAccentChoice: View {
    let option: DexterProductAccentOption
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(option.swatchColor)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 2)
                    )
                Text(option.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
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
    }
}

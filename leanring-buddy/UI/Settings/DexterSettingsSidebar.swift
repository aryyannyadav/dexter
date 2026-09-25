//
//  DexterSettingsSidebar.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSettingsSidebar: View {
    @ObservedObject var router: DexterSettingsRouter
    @Binding var searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DexterMetrics.space10) {
                DexterLogo(size: 20, style: .glow, animated: false)
                Text("Dexter")
                    .font(DexterSettingsTypography.windowBrand())
                    .foregroundColor(DexterColors.textPrimary)
            }
            .padding(.horizontal, DexterSettingsMetrics.sidebarHorizontalPadding)
            .padding(.top, DexterSettingsMetrics.sidebarTopPadding)
            .padding(.bottom, 12)

            DexterSettingsSearchField(placeholder: "Search settings", text: $searchText)
                .padding(.horizontal, DexterSettingsMetrics.sidebarHorizontalPadding)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: DexterSettingsMetrics.sidebarSectionSpacing) {
                    ForEach(DexterSettingsSidebarSectionKind.allCases, id: \.self) { section in
                        DexterSettingsSidebarSection(
                            section: section,
                            selectedPage: router.selectedPage,
                            onSelectPage: { router.open(page: $0) }
                        )
                    }
                }
                .padding(.horizontal, DexterSettingsMetrics.sidebarHorizontalPadding)
                .padding(.bottom, 16)
            }
        }
        .frame(width: DexterSettingsMetrics.sidebarWidth)
        .background(DexterSettingsColors.sidebarBackground)
        .overlay(
            Rectangle()
                .fill(DexterSettingsColors.separator)
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

private struct DexterSettingsSidebarSection: View {
    let section: DexterSettingsSidebarSectionKind
    let selectedPage: DexterSettingsPage
    let onSelectPage: (DexterSettingsPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.rawValue)
                .font(DexterSettingsTypography.sidebarSection())
                .foregroundColor(DS.Colors.textTertiary)
                .padding(.leading, 8)
                .padding(.bottom, 2)

            ForEach(section.pages) { page in
                DexterSettingsSidebarRow(
                    page: page,
                    isSelected: page == selectedPage,
                    onSelect: { onSelectPage(page) }
                )
            }
        }
    }
}

private struct DexterSettingsSidebarRow: View {
    let page: DexterSettingsPage
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: page.sidebarSystemImage)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14, alignment: .center)
                    .foregroundColor(isSelected ? DexterPastelColors.lavender : DexterColors.textSecondary)

                Text(page.navigationTitle)
                    .font(DexterSettingsTypography.sidebarRow())
                    .foregroundColor(isSelected ? DexterColors.textPrimary : DexterColors.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: DexterSettingsMetrics.sidebarRowHeight)
            .background(
                RoundedRectangle(cornerRadius: DexterSettingsMetrics.sidebarRowCornerRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(DexterPastelColors.lavender)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .accessibilityLabel(page.navigationTitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundFill: Color {
        if isSelected { return DexterSettingsColors.rowSelected }
        if isHovered { return DexterSettingsColors.rowHover }
        return Color.clear
    }
}

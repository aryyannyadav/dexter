//
//  DexterCapabilitiesSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterCapabilitiesSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var searchText = ""
    @State private var selectedCategory: DexterProductCapabilityCategory?
    @State private var selectedCapability: DexterProductCapability?

    private var capabilities: [DexterProductCapability] {
        companionManager.dexterProductCapabilities
    }

    private var filteredCapabilities: [DexterProductCapability] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return capabilities.filter { capability in
            let matchesCategory = selectedCategory == nil || capability.category == selectedCategory
            let matchesQuery = query.isEmpty
                || capability.displayName.lowercased().contains(query)
                || capability.description.lowercased().contains(query)
            return matchesCategory && matchesQuery
        }
    }

    var body: some View {
        DexterSettingsPageContainer(
            title: "Capabilities",
            subtitle: "What Dexter can do on this Mac, based on runtime discovery and permissions."
        ) {
            DexterSettingsSearchField(placeholder: "Search capabilities", text: $searchText)

            categoryFilter

            DexterSettingsSecondaryButton(
                title: companionManager.dexterIntegrationService.isRefreshing ? "Refreshing…" : "Refresh"
            ) {
                companionManager.refreshDexterProductCapabilities()
                companionManager.refreshDexterIntegrations()
            }
            .disabled(companionManager.dexterIntegrationService.isRefreshing)
            .padding(.top, 4)

            DexterSettingsSection(title: "SKILLS & TOOLS") {
                if filteredCapabilities.isEmpty {
                    Text("No capabilities match your filter.")
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DS.Colors.textTertiary)
                } else {
                    ForEach(filteredCapabilities) { capability in
                        Button {
                            selectedCapability = capability
                        } label: {
                            DexterProductCapabilitySettingsRow(capability: capability)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()
                        if capability.id != filteredCapabilities.last?.id {
                            DexterSettingsDivider()
                        }
                    }
                }
            }
        }
        .onAppear {
            companionManager.refreshDexterProductCapabilities()
        }
        .sheet(item: $selectedCapability) { capability in
            DexterCapabilityDetailSheet(capability: capability)
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "All", category: nil)
                ForEach(DexterProductCapabilityCategory.allCases, id: \.self) { category in
                    categoryChip(title: category.displayName, category: category)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func categoryChip(title: String, category: DexterProductCapabilityCategory?) -> some View {
        let isSelected = selectedCategory == category
        return Button(title) {
            selectedCategory = category
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(isSelected ? DexterColors.textPrimary : DexterColors.textTertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color.white.opacity(0.1) : DexterSettingsColors.searchFieldFill)
        )
        .pointerCursor()
    }
}

private struct DexterProductCapabilitySettingsRow: View {
    let capability: DexterProductCapability

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: capability.systemImageName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(capability.displayName)
                    .font(DexterSettingsTypography.rowTitle())
                    .foregroundColor(DS.Colors.textPrimary)
                Text(capability.description)
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(capability.availability.statusLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DS.Colors.textTertiary)
        }
        .accessibilityLabel("\(capability.displayName), \(capability.availability.statusLabel)")
    }
}

struct DexterCapabilityDetailSheet: View {
    let capability: DexterProductCapability
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.lg) {
            HStack(spacing: DexterSpacing.md) {
                Image(systemName: capability.systemImageName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(DexterPastelColors.lavender)
                VStack(alignment: .leading, spacing: 4) {
                    Text(capability.displayName)
                        .font(DexterTypography.display())
                    Text(capability.category.displayName)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .pointerCursor()
            }

            Text(capability.description)
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)

            detailRow(label: "Status", value: capability.availability.statusLabel)
            detailRow(label: "Provider", value: capability.providerSummary)
            if let permission = capability.requiresPermissionSummary {
                detailRow(label: "Permission", value: permission)
            }

            Spacer(minLength: 0)
        }
        .padding(DexterSpacing.xl)
        .frame(width: 420, height: 320)
        .background(DexterSurfaceColors.background)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
            Text(value)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterSurfaceColors.textPrimary)
        }
    }
}

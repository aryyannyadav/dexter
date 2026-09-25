//
//  DexterSettingsShell.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSettingsShell: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var router: DexterSettingsRouter
    @StateObject private var appearanceSettings = DexterAppearanceSettingsStore.shared
    @State private var settingsSearchText = ""

    var body: some View {
        HStack(spacing: 0) {
            DexterSettingsSidebar(
                router: router,
                searchText: $settingsSearchText
            )

            settingsPageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DexterSettingsColors.windowBackground)
        .preferredColorScheme(appearanceSettings.appearanceMode.preferredColorScheme ?? .dark)
    }

    @ViewBuilder
    private var settingsPageContent: some View {
        if settingsSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pageView(for: router.selectedPage)
        } else {
            searchResultsView
        }
    }

    private var searchResultsView: some View {
        let matches = DexterSettingsSearchIndex.matchingEntries(query: settingsSearchText)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search results")
                    .font(DexterSettingsTypography.pageTitle())
                    .foregroundColor(DS.Colors.textPrimary)

                if matches.isEmpty {
                    Text("No matching settings.")
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DS.Colors.textTertiary)
                } else {
                    ForEach(matches, id: \.self) { entry in
                        Button {
                            settingsSearchText = ""
                            router.open(page: entry.page)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(DexterSettingsTypography.rowTitle())
                                        .foregroundColor(DS.Colors.textPrimary)
                                    Text(entry.page.navigationTitle)
                                        .font(DexterSettingsTypography.rowSubtitle())
                                        .foregroundColor(DS.Colors.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DS.Colors.textTertiary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()
                    }
                }
            }
            .padding(DexterSettingsMetrics.contentPaddingHorizontal)
            .frame(maxWidth: DexterSettingsMetrics.contentMaxWidth, alignment: .leading)
        }
        .background(DexterSettingsColors.contentBackground)
    }

    @ViewBuilder
    private func pageView(for page: DexterSettingsPage) -> some View {
        switch page {
        case .general:
            DexterGeneralSettingsPage(companionManager: companionManager)
        case .appearance:
            DexterAppearanceSettingsPage()
        case .cursor:
            DexterCursorSettingsPage(companionManager: companionManager)
        case .voice:
            DexterVoiceSettingsPage(companionManager: companionManager)
        case .myDexters:
            DexterMyDextersSettingsPage(companionManager: companionManager)
        case .memory:
            DexterMemorySettingsPage(companionManager: companionManager)
        case .suggestions:
            DexterSuggestionsSettingsPage()
        case .screenContext:
            DexterScreenContextSettingsPage(companionManager: companionManager)
        case .computerControl:
            DexterComputerControlSettingsPage(companionManager: companionManager)
        case .integrations:
            DexterIntegrationsSettingsPage(companionManager: companionManager)
        case .privacy:
            DexterPrivacySettingsPage(companionManager: companionManager)
        case .permissions:
            DexterPermissionsSettingsPage(companionManager: companionManager)
        case .aiModels:
            DexterAIModelsSettingsPage(companionManager: companionManager)
        case .developer:
            DexterDeveloperSettingsPage(companionManager: companionManager)
        }
    }
}

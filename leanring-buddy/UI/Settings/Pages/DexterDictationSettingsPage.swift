//
//  DexterDictationSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterDictationSettingsPage: View {
    @StateObject private var dictationSettings = DexterDictationSettingsStore.shared
    @State private var languageSearchText: String = ""

    private var filteredLanguages: [DexterDictationLanguage] {
        let query = languageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return DexterDictationLanguageCatalog.seededLanguages }
        return DexterDictationLanguageCatalog.seededLanguages.filter {
            $0.displayName.lowercased().contains(query) || $0.localeCode.lowercased().contains(query)
        }
    }

    var body: some View {
        DexterSettingsPageContainer(
            title: "Dictation",
            subtitle: "Language preferences for speech recognition. Provider-specific language routing is applied when supported."
        ) {
            DexterSettingsSection(title: nil) {
                DexterSettingsToggleRow(
                    title: "Auto-detect language",
                    subtitle: "Let Dexter infer the spoken language when the STT backend supports it.",
                    isOn: $dictationSettings.isAutoDetectLanguageEnabled
                )
            }

            DexterSettingsSection(title: "Language") {
                DexterSettingsSearchField(placeholder: "Search languages", text: $languageSearchText)
                    .padding(.bottom, 8)

                DexterLanguageGrid(
                    languages: filteredLanguages,
                    selectedLanguageIdentifier: dictationSettings.selectedLanguageIdentifier,
                    onSelectLanguage: { language in
                        dictationSettings.selectedLanguageIdentifier = language.id
                    }
                )

                Text("Language preferences are saved and passed to the active speech-to-text provider when supported.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DexterLanguageGrid: View {
    let languages: [DexterDictationLanguage]
    let selectedLanguageIdentifier: String
    let onSelectLanguage: (DexterDictationLanguage) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 108, maximum: 140), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(languages) { language in
                DexterLanguageCell(
                    language: language,
                    isSelected: language.id == selectedLanguageIdentifier,
                    onSelect: { onSelectLanguage(language) }
                )
            }
        }
    }
}

struct DexterLanguageCell: View {
    let language: DexterDictationLanguage
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                Text(language.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(1)
                Text(language.localeCode)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? DexterSettingsColors.rowSelected : (isHovered ? DexterSettingsColors.rowHover : DexterSettingsColors.searchFieldFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? DexterIdentity.accentBorder : DexterSettingsColors.searchFieldBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .accessibilityLabel(language.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

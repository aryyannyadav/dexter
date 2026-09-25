//
//  DexterDictationSettingsStore.swift
//  leanring-buddy
//

import Combine
import Foundation

struct DexterDictationLanguage: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let localeCode: String
    let isAvailableForSelection: Bool
}

enum DexterDictationLanguageCatalog {
    static let seededLanguages: [DexterDictationLanguage] = [
        DexterDictationLanguage(id: "en", displayName: "English", localeCode: "en-US", isAvailableForSelection: true),
        DexterDictationLanguage(id: "es", displayName: "Spanish", localeCode: "es-ES", isAvailableForSelection: true),
        DexterDictationLanguage(id: "fr", displayName: "French", localeCode: "fr-FR", isAvailableForSelection: true),
        DexterDictationLanguage(id: "de", displayName: "German", localeCode: "de-DE", isAvailableForSelection: true),
        DexterDictationLanguage(id: "hi", displayName: "Hindi", localeCode: "hi-IN", isAvailableForSelection: true),
        DexterDictationLanguage(id: "zh", displayName: "Chinese", localeCode: "zh-CN", isAvailableForSelection: true),
        DexterDictationLanguage(id: "ja", displayName: "Japanese", localeCode: "ja-JP", isAvailableForSelection: true),
        DexterDictationLanguage(id: "ko", displayName: "Korean", localeCode: "ko-KR", isAvailableForSelection: true),
        DexterDictationLanguage(id: "pt", displayName: "Portuguese", localeCode: "pt-BR", isAvailableForSelection: true),
        DexterDictationLanguage(id: "ru", displayName: "Russian", localeCode: "ru-RU", isAvailableForSelection: true),
        DexterDictationLanguage(id: "ar", displayName: "Arabic", localeCode: "ar-SA", isAvailableForSelection: true),
        DexterDictationLanguage(id: "it", displayName: "Italian", localeCode: "it-IT", isAvailableForSelection: true),
        DexterDictationLanguage(id: "be", displayName: "Belarusian", localeCode: "be-BY", isAvailableForSelection: true),
        DexterDictationLanguage(id: "bn", displayName: "Bengali", localeCode: "bn-BD", isAvailableForSelection: true),
        DexterDictationLanguage(id: "bs", displayName: "Bosnian", localeCode: "bs-BA", isAvailableForSelection: true),
        DexterDictationLanguage(id: "bg", displayName: "Bulgarian", localeCode: "bg-BG", isAvailableForSelection: true),
        DexterDictationLanguage(id: "ca", displayName: "Catalan", localeCode: "ca-ES", isAvailableForSelection: true),
        DexterDictationLanguage(id: "hr", displayName: "Croatian", localeCode: "hr-HR", isAvailableForSelection: true),
        DexterDictationLanguage(id: "cs", displayName: "Czech", localeCode: "cs-CZ", isAvailableForSelection: true),
        DexterDictationLanguage(id: "da", displayName: "Danish", localeCode: "da-DK", isAvailableForSelection: true),
        DexterDictationLanguage(id: "nl", displayName: "Dutch", localeCode: "nl-NL", isAvailableForSelection: true),
        DexterDictationLanguage(id: "et", displayName: "Estonian", localeCode: "et-EE", isAvailableForSelection: true),
        DexterDictationLanguage(id: "fi", displayName: "Finnish", localeCode: "fi-FI", isAvailableForSelection: true),
        DexterDictationLanguage(id: "el", displayName: "Greek", localeCode: "el-GR", isAvailableForSelection: true),
        DexterDictationLanguage(id: "gu", displayName: "Gujarati", localeCode: "gu-IN", isAvailableForSelection: true),
        DexterDictationLanguage(id: "he", displayName: "Hebrew", localeCode: "he-IL", isAvailableForSelection: true),
        DexterDictationLanguage(id: "hu", displayName: "Hungarian", localeCode: "hu-HU", isAvailableForSelection: true),
        DexterDictationLanguage(id: "id", displayName: "Indonesian", localeCode: "id-ID", isAvailableForSelection: true),
        DexterDictationLanguage(id: "kn", displayName: "Kannada", localeCode: "kn-IN", isAvailableForSelection: true),
        DexterDictationLanguage(id: "lv", displayName: "Latvian", localeCode: "lv-LV", isAvailableForSelection: true),
        DexterDictationLanguage(id: "lt", displayName: "Lithuanian", localeCode: "lt-LT", isAvailableForSelection: true),
        DexterDictationLanguage(id: "mk", displayName: "Macedonian", localeCode: "mk-MK", isAvailableForSelection: true)
    ]
}

@MainActor
final class DexterDictationSettingsStore: ObservableObject {
    static let shared = DexterDictationSettingsStore()

    @Published var isAutoDetectLanguageEnabled: Bool {
        didSet { UserDefaults.standard.set(isAutoDetectLanguageEnabled, forKey: autoDetectLanguageKey) }
    }

    @Published var selectedLanguageIdentifier: String {
        didSet { UserDefaults.standard.set(selectedLanguageIdentifier, forKey: selectedLanguageKey) }
    }

    private let autoDetectLanguageKey = "dexterDictationAutoDetectLanguage"
    private let selectedLanguageKey = "dexterDictationSelectedLanguageIdentifier"

    private init() {
        isAutoDetectLanguageEnabled = UserDefaults.standard.object(forKey: autoDetectLanguageKey) as? Bool ?? true
        selectedLanguageIdentifier = UserDefaults.standard.string(forKey: selectedLanguageKey) ?? "en"
    }

    var selectedLanguage: DexterDictationLanguage? {
        DexterDictationLanguageCatalog.seededLanguages.first { $0.id == selectedLanguageIdentifier }
    }
}

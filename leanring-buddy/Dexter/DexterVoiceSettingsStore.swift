//
//  DexterVoiceSettingsStore.swift
//  leanring-buddy
//

import Foundation

struct DexterVoiceSettings: Equatable {
    /// When false, push-to-talk is ignored; text input still works.
    var isPushToTalkEnabled: Bool
    /// When false, responses appear as text only (no ElevenLabs playback).
    var isSpokenResponsesEnabled: Bool
    /// `AVSpeechSynthesisVoice.identifier` for local Mac TTS; nil uses Dexter's best-quality English default.
    var preferredMacSpeechVoiceIdentifier: String?

    static let `default` = DexterVoiceSettings(
        isPushToTalkEnabled: true,
        isSpokenResponsesEnabled: true,
        preferredMacSpeechVoiceIdentifier: nil
    )
}

protocol DexterVoiceSettingsStore: AnyObject {
    var currentSettings: DexterVoiceSettings { get set }
}

final class UserDefaultsDexterVoiceSettingsStore: DexterVoiceSettingsStore {
    private enum Keys {
        static let pushToTalkEnabled = "dexter.voice.pushToTalkEnabled"
        static let spokenResponsesEnabled = "dexter.voice.spokenResponsesEnabled"
        static let preferredMacSpeechVoiceIdentifier = "dexter.voice.preferredMacSpeechVoiceIdentifier"
    }

    var currentSettings: DexterVoiceSettings {
        get {
            let defaults = UserDefaults.standard
            let pushToTalkEnabled = defaults.object(forKey: Keys.pushToTalkEnabled) as? Bool ?? true
            let spokenResponsesEnabled = defaults.object(forKey: Keys.spokenResponsesEnabled) as? Bool ?? true
            let preferredMacSpeechVoiceIdentifier = defaults.string(forKey: Keys.preferredMacSpeechVoiceIdentifier)
            return DexterVoiceSettings(
                isPushToTalkEnabled: pushToTalkEnabled,
                isSpokenResponsesEnabled: spokenResponsesEnabled,
                preferredMacSpeechVoiceIdentifier: preferredMacSpeechVoiceIdentifier
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.isPushToTalkEnabled, forKey: Keys.pushToTalkEnabled)
            defaults.set(newValue.isSpokenResponsesEnabled, forKey: Keys.spokenResponsesEnabled)
            if let preferredMacSpeechVoiceIdentifier = newValue.preferredMacSpeechVoiceIdentifier {
                defaults.set(preferredMacSpeechVoiceIdentifier, forKey: Keys.preferredMacSpeechVoiceIdentifier)
            } else {
                defaults.removeObject(forKey: Keys.preferredMacSpeechVoiceIdentifier)
            }
        }
    }
}

final class InMemoryDexterVoiceSettingsStore: DexterVoiceSettingsStore {
    var currentSettings: DexterVoiceSettings

    init(currentSettings: DexterVoiceSettings = .default) {
        self.currentSettings = currentSettings
    }
}

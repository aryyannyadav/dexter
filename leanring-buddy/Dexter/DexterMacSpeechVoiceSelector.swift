//
//  DexterMacSpeechVoiceSelector.swift
//  leanring-buddy
//

import AVFoundation
import Foundation

enum DexterMacSpeechVoiceSelector {
    static func availableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                voice.language.lowercased().hasPrefix("en")
            }
            .sorted { lhs, rhs in
                qualityRank(for: lhs) > qualityRank(for: rhs)
            }
    }

    static func resolveVoice(preferredVoiceIdentifier: String?) -> AVSpeechSynthesisVoice? {
        if let preferredVoiceIdentifier,
           let preferredVoice = AVSpeechSynthesisVoice(identifier: preferredVoiceIdentifier) {
            return preferredVoice
        }
        return bestDefaultEnglishVoice()
    }

    static func bestDefaultEnglishVoice() -> AVSpeechSynthesisVoice? {
        let unitedStatesEnglishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" }
            .sorted { qualityRank(for: $0) > qualityRank(for: $1) }

        if #available(macOS 13.0, *) {
            let femaleUnitedStatesVoices = unitedStatesEnglishVoices.filter { $0.gender == .female }
            if let bestFemaleVoice = femaleUnitedStatesVoices.first {
                return bestFemaleVoice
            }
        }

        let preferredNames = [
            "Samantha",
            "Ava",
            "Allison",
            "Susan",
            "Karen",
            "Tessa",
            "Serena",
            "Zoe"
        ]

        for preferredName in preferredNames {
            if let match = unitedStatesEnglishVoices.first(where: { $0.name.localizedCaseInsensitiveContains(preferredName) }) {
                return match
            }
        }

        return unitedStatesEnglishVoices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private static func qualityRank(for voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium: return 4
        case .enhanced: return 3
        default: return 1
        }
    }
}

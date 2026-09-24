//
//  DexterTTSProvider.swift
//  leanring-buddy
//

import AVFoundation
import Foundation

protocol DexterTTSProvider: AnyObject {
    func speak(_ text: String) async throws
    func stopSpeaking()
    var isSpeaking: Bool { get }
}

/// Offline-friendly speech using macOS `AVSpeechSynthesizer`.
@MainActor
final class LocalMacTTSProvider: NSObject, DexterTTSProvider {
    private let synthesizer = AVSpeechSynthesizer()
    private var speakContinuation: CheckedContinuation<Void, Error>?
    private var preferredVoiceIdentifier: String?

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    func setPreferredVoiceIdentifier(_ voiceIdentifier: String?) {
        preferredVoiceIdentifier = voiceIdentifier
    }

    func speak(_ text: String) async throws {
        stopSpeaking()

        let spokenText = DexterSpeechTextCleaner.spokenText(from: text)
        guard !spokenText.isEmpty else { return }

        try Task.checkCancellation()

        let utterance = AVSpeechUtterance(string: spokenText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.volume = 1
        utterance.preUtteranceDelay = 0.04
        utterance.postUtteranceDelay = 0.12

        let selectedVoice = DexterMacSpeechVoiceSelector.resolveVoice(preferredVoiceIdentifier: preferredVoiceIdentifier)
        utterance.voice = selectedVoice
        DexterDiagnosticLog.tts("local voice selected: \(selectedVoice?.name ?? "system default") (\(selectedVoice?.language ?? "unknown"))")

        synthesizer.delegate = self

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            speakContinuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if let speakContinuation {
            speakContinuation.resume(throwing: CancellationError())
            self.speakContinuation = nil
        }
    }
}

extension LocalMacTTSProvider: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DexterDiagnosticLog.tts("playback started (local Mac voice)")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            DexterDiagnosticLog.tts("playback completed (local Mac voice)")
            speakContinuation?.resume()
            speakContinuation = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            DexterDiagnosticLog.tts("playback cancelled (local Mac voice)")
            if speakContinuation != nil {
                speakContinuation?.resume(throwing: CancellationError())
                speakContinuation = nil
            }
        }
    }
}

@MainActor
final class ElevenLabsTTSProvider: DexterTTSProvider {
    private let elevenLabsTTSClient: ElevenLabsTTSClient

    var isSpeaking: Bool {
        elevenLabsTTSClient.isPlaying
    }

    init(elevenLabsTTSClient: ElevenLabsTTSClient) {
        self.elevenLabsTTSClient = elevenLabsTTSClient
    }

    func speak(_ text: String) async throws {
        let spokenText = DexterSpeechTextCleaner.spokenText(from: text)
        try await elevenLabsTTSClient.speakText(spokenText)
    }

    func stopSpeaking() {
        elevenLabsTTSClient.stopPlayback()
    }
}

/// Speaks assistant replies with local Mac TTS first; ElevenLabs remains an optional cloud fallback.
@MainActor
final class DexterSpokenResponseService {
    private let localMacTTSProvider = LocalMacTTSProvider()
    private let elevenLabsTTSProvider: ElevenLabsTTSProvider
    private let voiceSettingsStore: DexterVoiceSettingsStore

    var isSpeaking: Bool {
        localMacTTSProvider.isSpeaking || elevenLabsTTSProvider.isSpeaking
    }

    init(elevenLabsTTSClient: ElevenLabsTTSClient, voiceSettingsStore: DexterVoiceSettingsStore) {
        elevenLabsTTSProvider = ElevenLabsTTSProvider(elevenLabsTTSClient: elevenLabsTTSClient)
        self.voiceSettingsStore = voiceSettingsStore
    }

    func speakAssistantResponse(_ text: String) async throws {
        localMacTTSProvider.setPreferredVoiceIdentifier(
            voiceSettingsStore.currentSettings.preferredMacSpeechVoiceIdentifier
        )

        if DexterWorkerProxyClient.isWorkerBaseURLConfigured {
            DexterDiagnosticLog.tts("provider=elevenlabs")
            do {
                try await elevenLabsTTSProvider.speak(text)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                DexterDiagnosticLog.tts("ElevenLabs unavailable — using local Mac fallback")
            }
        } else {
            DexterDiagnosticLog.tts("ElevenLabs unavailable — using local Mac fallback")
        }

        DexterDiagnosticLog.tts("provider=local_mac")
        DexterDiagnosticLog.tts("synthesis started")
        try await localMacTTSProvider.speak(text)
    }

    func stopSpeaking() {
        localMacTTSProvider.stopSpeaking()
        elevenLabsTTSProvider.stopSpeaking()
    }
}

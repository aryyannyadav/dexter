//
//  DexterVoiceCoordinator.swift
//  leanring-buddy
//

import Combine
import Foundation

/// Coordinates push-to-talk dictation signals into Dexter Voice interaction state.
/// Does not own transcription or TTS implementations — only lifecycle and settings.
@MainActor
final class DexterVoiceCoordinator: ObservableObject {
    @Published private(set) var interactionState: DexterVoiceInteractionState = .idle
    @Published private(set) var streamingResponseText: String = ""
    @Published private(set) var lastAssistantResponseText: String = ""

    let settingsStore: DexterVoiceSettingsStore

    private var dictationStateCancellable: AnyCancellable?

    init(settingsStore: DexterVoiceSettingsStore = UserDefaultsDexterVoiceSettingsStore()) {
        self.settingsStore = settingsStore
    }

    var voiceSettings: DexterVoiceSettings {
        get { settingsStore.currentSettings }
        set { settingsStore.currentSettings = newValue }
    }

    func bindDictationManager(_ dictationManager: BuddyDictationManager) {
        dictationStateCancellable = dictationManager.$isRecordingFromKeyboardShortcut
            .combineLatest(
                dictationManager.$isRecordingFromMicrophoneButton,
                dictationManager.$isFinalizingTranscript,
                dictationManager.$isPreparingToRecord
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecordingFromShortcut, isRecordingFromMicButton, isFinalizing, isPreparing in
                self?.applyDictationSignals(
                    isRecording: isRecordingFromShortcut || isRecordingFromMicButton,
                    isFinalizing: isFinalizing,
                    isPreparing: isPreparing
                )
            }
    }

    func resetStreamingResponseText() {
        streamingResponseText = ""
    }

    /// Accepts either incremental deltas (Ollama) or full accumulated text (Claude SSE).
    func appendStreamingResponseChunk(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        if chunk.count >= streamingResponseText.count,
           chunk.hasPrefix(streamingResponseText) {
            streamingResponseText = chunk
        } else {
            streamingResponseText += chunk
        }
    }

    func recordAssistantResponse(_ text: String) {
        lastAssistantResponseText = text
        streamingResponseText = text
    }

    func transitionToThinking() {
        interactionState = .thinking
    }

    func transitionToSpeaking() {
        interactionState = .speaking
    }

    func transitionToIdle() {
        interactionState = .idle
    }

    func transitionToTranscribing() {
        interactionState = .transcribing
    }

    func transitionToError() {
        interactionState = .error
    }

    func clearVoiceInputError() {
        if interactionState == .error {
            interactionState = .idle
        }
    }

    /// Called when the user interrupts (new PTT press or cancel). Stops treating speaking/thinking as blocking dictation UI.
    func handleUserInterruption() {
        if interactionState == .speaking || interactionState == .thinking {
            interactionState = .idle
        }
    }

    /// Natural turn-taking: user takes the floor — end assistant speaking/thinking before mic capture.
    func prepareForPushToTalkCapture() {
        if interactionState == .error {
            interactionState = .idle
        }
        handleUserInterruption()
    }

    private func applyDictationSignals(
        isRecording: Bool,
        isFinalizing: Bool,
        isPreparing: Bool
    ) {
        guard settingsStore.currentSettings.isPushToTalkEnabled else { return }

        // Speaking is interrupted by push-to-talk; show listening as soon as capture starts.
        if interactionState == .speaking {
            if isRecording || isPreparing {
                interactionState = .listening
            }
            return
        }

        // Orchestrator "thinking" owns the panel until STT finishes or a new recording starts.
        if interactionState == .thinking {
            if isRecording || isPreparing {
                interactionState = .listening
            }
            return
        }

        if isRecording || isPreparing {
            interactionState = .listening
        } else if isFinalizing {
            interactionState = .transcribing
        } else if interactionState == .listening {
            interactionState = .idle
        }
    }
}

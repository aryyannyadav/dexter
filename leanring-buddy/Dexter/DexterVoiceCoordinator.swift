//
//  DexterVoiceCoordinator.swift
//  leanring-buddy
//

import Combine
import Foundation

enum DexterVoiceUserMessageSource: Equatable {
    case pushToTalkTranscript
    case typedText
}

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
                dictationManager.$isFinalizingTranscript,
                dictationManager.$isPreparingToRecord
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, isFinalizing, isPreparing in
                self?.applyDictationSignals(
                    isRecording: isRecording,
                    isFinalizing: isFinalizing,
                    isPreparing: isPreparing
                )
            }
    }

    func resetStreamingResponseText() {
        streamingResponseText = ""
    }

    func appendStreamingResponseChunk(_ chunk: String) {
        streamingResponseText += chunk
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

    /// Called when the user interrupts (new PTT press or cancel). Stops treating speaking/thinking as blocking dictation UI.
    func handleUserInterruption() {
        if interactionState == .speaking || interactionState == .thinking {
            interactionState = .idle
        }
    }

    private func applyDictationSignals(
        isRecording: Bool,
        isFinalizing: Bool,
        isPreparing: Bool
    ) {
        guard settingsStore.currentSettings.isPushToTalkEnabled else { return }

        // Allow dictation-driven state while thinking; speaking is interrupted explicitly elsewhere.
        if interactionState == .speaking {
            return
        }

        if isFinalizing || isPreparing {
            interactionState = .thinking
        } else if isRecording {
            interactionState = .listening
        } else if interactionState == .listening || interactionState == .thinking {
            // Release without finalize path is handled by the response pipeline.
            if interactionState == .listening {
                interactionState = .idle
            }
        }
    }
}

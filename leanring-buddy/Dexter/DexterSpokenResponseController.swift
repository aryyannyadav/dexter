//
//  DexterSpokenResponseController.swift
//  leanring-buddy
//

import Foundation

enum DexterSpokenResponseController {
    @MainActor
    static func speakAssistantTextIfEnabled(
        text: String,
        voiceSettings: DexterVoiceSettings,
        spokenResponseService: DexterSpokenResponseService,
        voiceCoordinator: DexterVoiceCoordinator
    ) async -> DexterSpokenResponseOutcome {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return .skippedEmptyText
        }
        guard voiceSettings.isSpokenResponsesEnabled else {
            return .skippedDisabled
        }

        DexterCoreExecutionPipelineLog.log(phase: .textToSpeech)
        voiceCoordinator.transitionToSpeaking()

        do {
            try await DexterPerformanceTiming.measure(bucket: .tts) {
                try await spokenResponseService.speakAssistantResponse(trimmedText)
            }
            if voiceCoordinator.interactionState == .speaking {
                voiceCoordinator.transitionToIdle()
            }
            return .completed
        } catch is CancellationError {
            DexterDiagnosticLog.tts("playback cancelled")
            if voiceCoordinator.interactionState == .speaking {
                voiceCoordinator.transitionToIdle()
            }
            return .cancelled
        } catch {
            DexterAnalytics.trackTTSError(error: error.localizedDescription)
            DexterDiagnosticLog.tts("playback failed")
            if voiceCoordinator.interactionState == .speaking {
                voiceCoordinator.transitionToIdle()
            }
            return .failed(error)
        }
    }
}

enum DexterSpokenResponseOutcome: Equatable {
    case completed
    case cancelled
    case skippedEmptyText
    case skippedDisabled
    case failed(Error)

    static func == (lhs: DexterSpokenResponseOutcome, rhs: DexterSpokenResponseOutcome) -> Bool {
        switch (lhs, rhs) {
        case (.completed, .completed),
             (.cancelled, .cancelled),
             (.skippedEmptyText, .skippedEmptyText),
             (.skippedDisabled, .skippedDisabled):
            return true
        case (.failed(let leftError), .failed(let rightError)):
            return leftError.localizedDescription == rightError.localizedDescription
        default:
            return false
        }
    }
}

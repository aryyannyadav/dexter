//
//  DexterVoiceCoreRuntimeTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterVoiceCoreRuntimeTests {
    @Test func pushToTalkReleaseIsIdempotentPerSession() {
        let tracker = DexterPushToTalkSessionTracker()
        let sessionIdentifier = tracker.beginSession()

        #expect(tracker.handleRelease(for: sessionIdentifier))
        #expect(!tracker.handleRelease(for: sessionIdentifier))
    }

    @Test func pushToTalkReleaseIgnoresUnknownSession() {
        let tracker = DexterPushToTalkSessionTracker()
        let sessionIdentifier = tracker.beginSession()
        #expect(!tracker.handleRelease(for: UUID()))
        #expect(tracker.handleRelease(for: sessionIdentifier))
    }

    @Test func normalizedTranscriptRejectsWhitespaceOnly() {
        #expect(DexterUserTurnExecutor.normalizedTranscript("  \n  ").isEmpty)
        #expect(DexterUserTurnExecutor.normalizedTranscript(" open safari ") == "open safari")
    }

    @Test func voiceAndTextShareCorePromptExceptVoiceSupplement() {
        let baseSystemPrompt = "DEXTER_BASE"
        let typedPrompt = DexterUserTurnExecutor.resolvedSystemPrompt(
            baseSystemPrompt: baseSystemPrompt,
            inputChannel: .typedText
        )
        let voicePrompt = DexterUserTurnExecutor.resolvedSystemPrompt(
            baseSystemPrompt: baseSystemPrompt,
            inputChannel: .pushToTalkTranscript
        )

        #expect(typedPrompt == baseSystemPrompt)
        #expect(voicePrompt.hasPrefix(baseSystemPrompt))
        #expect(voicePrompt.count > baseSystemPrompt.count)
    }

    @Test func userTurnControllerTracksActiveGenerations() {
        let controller = DexterUserTurnController()
        let firstGeneration = controller.beginTurn()
        let secondGeneration = controller.beginTurn()

        #expect(secondGeneration > firstGeneration)
        #expect(controller.isTurnStillActive(generation: secondGeneration))
        #expect(!controller.isTurnStillActive(generation: firstGeneration))
    }

    @Test func voiceCoordinatorInterruptionForNewCapture() {
        let coordinator = DexterVoiceCoordinator(settingsStore: InMemoryDexterVoiceSettingsStore())
        coordinator.transitionToSpeaking()
        coordinator.prepareForPushToTalkCapture()
        #expect(coordinator.interactionState == .idle)
    }

    @Test func spokenResponseSkipsWhenDisabled() async {
        let coordinator = DexterVoiceCoordinator(
            settingsStore: InMemoryDexterVoiceSettingsStore(
                currentSettings: DexterVoiceSettings(
                    isPushToTalkEnabled: true,
                    isSpokenResponsesEnabled: false,
                    preferredMacSpeechVoiceIdentifier: nil
                )
            )
        )
        let outcome = await DexterSpokenResponseController.speakAssistantTextIfEnabled(
            text: "Hello",
            voiceSettings: coordinator.voiceSettings,
            spokenResponseService: DexterSpokenResponseService(
                elevenLabsTTSClient: ElevenLabsTTSClient(proxyURL: "https://example.test/tts"),
                voiceSettingsStore: coordinator.settingsStore
            ),
            voiceCoordinator: coordinator
        )
        #expect(outcome == .skippedDisabled)
        #expect(coordinator.interactionState == .idle)
    }

    @Test func pipelineDocumentsVoiceToResponsePhases() {
        let phaseNames = DexterCoreExecutionPipelinePhase.allCases.map(\.rawValue)
        #expect(phaseNames.contains("PTT"))
        #expect(phaseNames.contains("STT"))
        #expect(phaseNames.contains("INTENT"))
        #expect(phaseNames.contains("TTS"))
    }

    @Test func actIntentUsesSameStructuredRoutingAsText() {
        let intent = DexterIntentRouter.recognize(
            userMessage: "open safari",
            context: DexterContext(userMessage: DexterUserMessageContext(text: "open safari"))
        )
        #expect(intent.kind == .open)
        let responseMode = DexterIntentResponseModeMapper.responseMode(for: intent)
        #expect(responseMode == .act)
    }
}

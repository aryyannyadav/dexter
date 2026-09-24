//
//  DexterUserTurnController.swift
//  leanring-buddy
//

import Foundation

/// Cancels in-flight model/TTS/action work and coordinates natural turn-taking for voice.
@MainActor
final class DexterUserTurnController {
    let pushToTalkSessionTracker = DexterPushToTalkSessionTracker()

    private(set) var activeTurnGeneration: UInt64 = 0
    private var responseTask: Task<Void, Never>?

    var hasActiveResponseTask: Bool {
        responseTask != nil
    }

    func beginTurn() -> UInt64 {
        activeTurnGeneration += 1
        return activeTurnGeneration
    }

    func isTurnStillActive(generation: UInt64) -> Bool {
        generation == activeTurnGeneration
    }

    func setResponseTask(_ task: Task<Void, Never>?) {
        responseTask = task
    }

    func cancelActiveTurn(
        spokenResponseService: DexterSpokenResponseService,
        voiceCoordinator: DexterVoiceCoordinator,
        orchestrator: DexterOrchestrator
    ) {
        responseTask?.cancel()
        responseTask = nil
        activeTurnGeneration += 1

        spokenResponseService.stopSpeaking()
        voiceCoordinator.handleUserInterruption()

        Task {
            await orchestrator.cancelInFlightComputerActionIfNeeded()
        }
    }
}

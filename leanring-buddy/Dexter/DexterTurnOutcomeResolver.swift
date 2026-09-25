//
//  DexterTurnOutcomeResolver.swift
//  leanring-buddy
//

import Foundation

/// Maps orchestrator action state to turn-level observability outcomes (never treat failed actions as SUCCESS).
enum DexterTurnOutcomeResolver {
    @MainActor
    static func resolve(
        orchestrator: DexterOrchestrator,
        orchestratorResponse: DexterOrchestratorModelResponse
    ) -> DexterTurnOutcome {
        resolve(
            hasPendingActionConfirmation: orchestrator.pendingActionExecution != nil,
            responseMode: orchestratorResponse.responseMode,
            lastActionState: orchestrator.lastTypedAction?.state
        )
    }

    static func resolve(
        hasPendingActionConfirmation: Bool,
        responseMode: DexterResponseMode,
        lastActionState: DexterActionState?
    ) -> DexterTurnOutcome {
        if hasPendingActionConfirmation {
            return .success
        }

        guard responseMode == .act, let lastActionState else {
            return .success
        }

        return resolveAfterActionExecution(actionState: lastActionState)
    }

    static func resolveAfterApprovedActionExecution(outcome: DexterActionExecutionOutcome) -> DexterTurnOutcome {
        resolveAfterActionExecution(actionState: outcome.action.state)
    }

    static func resolveAfterActionExecution(actionState: DexterActionState) -> DexterTurnOutcome {
        switch actionState {
        case .completed:
            return .success
        case .cancelled:
            return .cancelled
        case .failed, .verificationFailed:
            return .error
        case .awaitingConfirmation:
            return .success
        case .proposed, .approved, .executing:
            return .error
        }
    }

    @MainActor
    static func operationalOutcome(
        for turnOutcome: DexterTurnOutcome,
        orchestrator: DexterOrchestrator
    ) -> DexterOperationalOutcomeCategory {
        if turnOutcome == .error,
           let snapshot = orchestrator.lastExecutionSnapshot,
           snapshot.currentPhase == .failed,
           snapshot.errorInfo?.code == "verification_failed" {
            return .verificationFailed
        }
        return DexterTaskTraceRecorder.mapTurnOutcome(turnOutcome)
    }
}

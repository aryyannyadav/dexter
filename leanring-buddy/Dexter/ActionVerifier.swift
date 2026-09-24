//
//  ActionVerifier.swift
//  leanring-buddy
//

import Foundation

struct ActionVerificationOutcome: Equatable {
    let status: DexterActionVerificationStatus
    let summary: String
    let report: DexterActionVerificationReport

    var wasSuccessful: Bool {
        status == .verified || status == .partiallyVerified
    }
}

/// Observes fresh environment state and verifies intended vs actual outcomes.
protocol ActionVerifier: AnyObject {
    func verify(
        action: DexterAction,
        executionResult: AgentActionResult,
        observationBefore: DexterActionObservationSnapshot,
        observationAfter: DexterActionObservationSnapshot
    ) async -> ActionVerificationOutcome
}

@MainActor
final class ObservingActionVerifier: ActionVerifier {
    func verify(
        action: DexterAction,
        executionResult: AgentActionResult,
        observationBefore: DexterActionObservationSnapshot,
        observationAfter: DexterActionObservationSnapshot
    ) async -> ActionVerificationOutcome {
        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: observationBefore,
            observationAfter: observationAfter,
            executionResult: executionResult
        )
        return ActionVerificationOutcome(status: report.status, summary: report.summary, report: report)
    }
}

/// Fallback verifier for tests that supply fixed observation snapshots out of band.
final class StubActionVerifier: ActionVerifier {
    var nextOutcome: ActionVerificationOutcome?

    func verify(
        action: DexterAction,
        executionResult: AgentActionResult,
        observationBefore: DexterActionObservationSnapshot,
        observationAfter: DexterActionObservationSnapshot
    ) async -> ActionVerificationOutcome {
        if let nextOutcome {
            return nextOutcome
        }
        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: observationBefore,
            observationAfter: observationAfter,
            executionResult: executionResult
        )
        return ActionVerificationOutcome(status: report.status, summary: report.summary, report: report)
    }
}

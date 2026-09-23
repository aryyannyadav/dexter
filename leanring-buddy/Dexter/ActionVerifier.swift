//
//  ActionVerifier.swift
//  leanring-buddy
//

import Foundation

enum ActionVerificationConfidence: Equatable {
    case certain
    case uncertain
}

struct ActionVerificationOutcome: Equatable {
    let wasSuccessful: Bool
    let summary: String
    let confidence: ActionVerificationConfidence
}

/// Observes and verifies whether an executed action achieved the intended effect.
protocol ActionVerifier: AnyObject {
    func verify(
        actionRequest: AgentActionRequest,
        executionResult: AgentActionResult,
        context: DexterContext
    ) async -> ActionVerificationOutcome
}

/// Minimal verifier: trusts runtime success flag but reports uncertainty (no observation yet).
final class UncertainActionVerifier: ActionVerifier {
    func verify(
        actionRequest: AgentActionRequest,
        executionResult: AgentActionResult,
        context: DexterContext
    ) async -> ActionVerificationOutcome {
        ActionVerificationOutcome(
            wasSuccessful: executionResult.reportedSuccess,
            summary: executionResult.message,
            confidence: .uncertain
        )
    }
}

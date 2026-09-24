//
//  DexterActionVerificationRecoveryPolicy.swift
//  leanring-buddy
//
//  Verification failure handling: only explicitly defined safe retries—never destructive replays.
//

import Foundation

enum DexterActionVerificationRecoveryKind: Equatable {
    case none
    case retrySameLowRiskNavigationOnce
}

enum DexterActionVerificationRecoveryPolicy {
    static func recoveryKindAfterVerificationFailure(
        action: DexterAction,
        metadata: DexterActionRecoveryMetadata
    ) -> DexterActionVerificationRecoveryKind {
        guard metadata.reversible else {
            return .none
        }

        switch action.type {
        case .openApplication, .focusApplication, .openURL, .navigate:
            guard DexterActionSafeRetryPolicy.canAttemptSafeRetry(for: action) else {
                return .none
            }
            return .retrySameLowRiskNavigationOnce

        case .scroll:
            return .none

        case .inspectScreen, .explainContent, .click, .typeText, .keyboardShortcut, .select,
             .runTask, .quitApplication, .fileOperation, .terminalOperation:
            return .none
        }
    }

    static func shouldRetrySameActionAfterVerificationFailure(
        action: DexterAction,
        metadata: DexterActionRecoveryMetadata,
        didAlreadyAttemptRecovery: Bool
    ) -> Bool {
        guard !didAlreadyAttemptRecovery else { return false }
        return recoveryKindAfterVerificationFailure(action: action, metadata: metadata)
            == .retrySameLowRiskNavigationOnce
    }
}

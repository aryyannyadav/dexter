//
//  DexterTurnOutcomeResolverTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterTurnOutcomeResolverTests {
    @Test func failedVerifiedActionTurnIsErrorNotSuccess() {
        let turnOutcome = DexterTurnOutcomeResolver.resolve(
            hasPendingActionConfirmation: false,
            responseMode: .act,
            lastActionState: .verificationFailed
        )
        #expect(turnOutcome == .error)
    }

    @Test func pendingConfirmationTurnRemainsSuccess() {
        let turnOutcome = DexterTurnOutcomeResolver.resolve(
            hasPendingActionConfirmation: true,
            responseMode: .act,
            lastActionState: .awaitingConfirmation
        )
        #expect(turnOutcome == .success)
    }

    @Test func openClawDispatchFailureMapsToErrorTurnOutcome() {
        let turnOutcome = DexterTurnOutcomeResolver.resolveAfterActionExecution(actionState: .verificationFailed)
        #expect(turnOutcome == .error)
    }

    @Test func cancelledActionMapsToCancelledTurnOutcome() {
        let turnOutcome = DexterTurnOutcomeResolver.resolveAfterActionExecution(actionState: .cancelled)
        #expect(turnOutcome == .cancelled)
    }
}

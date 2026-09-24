//
//  DexterInteractiveOnboardingTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

@MainActor
struct DexterInteractiveOnboardingTests {
    @Test func experientialFlowAdvancesThroughPointExplainAndAction() {
        let store = DexterInteractiveOnboardingStore()
        store.beginInteractiveOnboarding()
        #expect(store.phase == .awaitingPoint)
        #expect(store.overlayPrompt == "Point at anything.")

        store.registerPointCaptureIfNeeded()
        #expect(store.phase == .awaitingExplainQuestion)
        #expect(store.overlayPrompt == "Now ask me what it is.")

        store.registerExplainTurnCompletedIfNeeded()
        #expect(store.phase == .awaitingActionRequest)
        #expect(store.overlayPrompt.contains("do something"))

        store.registerActionRequestStartedIfNeeded()
        #expect(store.phase == .awaitingActionOutcome)

        store.registerVerifiedActionCompletedIfNeeded()
        #expect(store.phase == .finale)
        #expect(store.overlayPrompt == DexterInteractiveOnboardingPolicy.finaleMessage)
    }

    @Test func onboardingActionPolicyAllowsCalculator() {
        let action = DexterActionFactory.openApplication(named: "Calculator")
        #expect(DexterInteractiveOnboardingPolicy.shouldAutoApproveOnboardingAction(action: action))
    }
}

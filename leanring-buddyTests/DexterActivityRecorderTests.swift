//
//  DexterActivityRecorderTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterActivityRecorderTests {
    @Test func actionOutcomeRecordsVerifiedActivity() {
        let recorder = DexterActivityRecorder.inMemoryForTesting()
        let action = DexterAction.openApplication(named: "Safari", contextSummary: nil)
        let turnRecord = DexterActionTurnRecord(
            actionIdentifier: action.id,
            intentSummary: "open_application",
            targetSummary: "Safari",
            runtimeName: "OpenClaw",
            runtimeExecutionIdentifier: nil,
            startedAt: Date(),
            endedAt: Date(),
            resultStatus: .succeeded,
            verificationStatus: .verified,
            userFacingExplanation: "Safari is running."
        )
        let outcome = DexterActionExecutionOutcome(
            action: action.withState(.completed),
            spokenSummary: "Safari is running.",
            pendingConfirmation: nil,
            verificationReport: nil,
            turnRecord: turnRecord,
            executionSnapshot: nil,
            recoveryMetadata: nil
        )

        recorder.recordActionExecutionOutcome(
            outcome: outcome,
            linkage: DexterActivityLinkage(dexterProfileId: UUID(), conversationId: nil, fileWorkspaceId: nil),
            userRequest: "Open Safari"
        )

        #expect(recorder.events.count == 1)
        #expect(recorder.events.first?.kind == .action)
        #expect(recorder.events.first?.status == .verified)
        #expect(recorder.events.first?.title.contains("Safari") == true)
    }

    @Test func sensitiveMemoryContentIsNotRecordedInActivity() {
        let recorder = DexterActivityRecorder.inMemoryForTesting()
        let memory = DexterStructuredMemoryRecord(
            type: .semantic,
            content: "remember api_key sk-abcdefghijklmnopqrstuvwxyz",
            source: .explicitUserUtterance,
            confidence: 0.9,
            importance: 0.8,
            permissions: .defaultForExplicitUser,
            title: "Secret"
        )
        recorder.recordMemorySaved(memory)
        #expect(recorder.events.isEmpty)
    }
}

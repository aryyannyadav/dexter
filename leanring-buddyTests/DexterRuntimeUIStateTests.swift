//
//  DexterRuntimeUIStateTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterRuntimeUIStateTests {
    @Test func verifyingSnapshotNeverMapsToDone() {
        let snapshot = DexterExecutionMachineSnapshot(
            executionIdentifier: UUID(),
            actionIdentifier: UUID(),
            parentTaskIdentifier: nil,
            currentPhase: .verifying,
            progressSummary: "Comparing intended vs observed state.",
            receivedAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            stepCount: 4,
            actionBudget: 3,
            toolBudget: 5,
            actionsConsumed: 1,
            toolsConsumed: 1,
            isCancellationRequested: false,
            timeoutSeconds: 120,
            errorInfo: nil,
            verificationStatus: nil
        )

        let resolved = DexterRuntimeUIStateResolver.resolve(
            executionSnapshot: snapshot,
            voiceInteractionState: .idle,
            orchestratorPhaseOverride: .done,
            orchestratorDetailOverride: "Response ready"
        )

        #expect(resolved.state == .verifying)
        #expect(resolved.detail == "Checking…")
    }

    @Test func failedSnapshotIncludesRecoveryGuidance() {
        let snapshot = DexterExecutionMachineSnapshot(
            executionIdentifier: UUID(),
            actionIdentifier: UUID(),
            parentTaskIdentifier: nil,
            currentPhase: .failed,
            progressSummary: "Permission denied",
            receivedAt: Date(),
            updatedAt: Date(),
            completedAt: Date(),
            stepCount: 2,
            actionBudget: 3,
            toolBudget: 5,
            actionsConsumed: 0,
            toolsConsumed: 0,
            isCancellationRequested: false,
            timeoutSeconds: 120,
            errorInfo: DexterExecutionErrorInfo(code: "permission_denied", message: "Screen recording is required."),
            verificationStatus: nil
        )

        let resolved = DexterRuntimeUIStateResolver.resolve(
            executionSnapshot: snapshot,
            voiceInteractionState: .idle,
            orchestratorPhaseOverride: nil,
            orchestratorDetailOverride: ""
        )

        #expect(resolved.state == .failed)
        #expect(resolved.failurePresentation != nil)
        #expect(resolved.failurePresentation?.whatYouCanDoNext.contains("permission") == true)
    }
}

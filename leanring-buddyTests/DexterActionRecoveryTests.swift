//
//  DexterActionRecoveryTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterActionRecoveryTests {
    @Test func openApplicationIsReversibleWithFocusRollback() {
        let before = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeApplicationLocalizedName: "Safari",
            activeWindowTitle: "Apple",
            pointerElementTitle: nil,
            pointerElementRoleDescription: nil,
            pointerElementValueDescription: nil,
            browserState: .empty,
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let action = DexterActionFactory.openApplication(named: "Visual Studio Code")
        let profile = DexterActionRecoveryMetadataBuilder.recoveryProfile(
            for: action,
            observationBefore: before
        )

        #expect(profile.reversible)
        #expect(profile.rollbackStrategy == .focusPreviousApplication(applicationName: "Safari"))
    }

    @Test func clickIsIrreversibleAndRequiresConfirmationEvenWhenLowRisk() {
        let before = DexterActionObservationSnapshot.empty
        let clickAction = DexterActionFactory.click(x: "10", y: "20", label: "Save")
        let profile = DexterActionRecoveryMetadataBuilder.recoveryProfile(
            for: clickAction,
            observationBefore: before
        )

        #expect(!profile.reversible)
        if case .notSupported = profile.rollbackStrategy {
            #expect(Bool(true))
        } else {
            Issue.record("Expected notSupported rollback strategy for click")
        }

        let settings = DexterActionPermissionSettings(autoApproveLowRiskActions: true)
        let requiresConfirmation = DexterActionConfirmationPolicy.requiresUserConfirmation(
            action: clickAction,
            settings: settings,
            confirmationGrant: nil,
            observationBefore: before
        )
        #expect(requiresConfirmation)
    }

    @Test func verificationRecoveryDoesNotRetryDestructiveActions() {
        let before = DexterActionObservationSnapshot.empty
        let clickAction = DexterActionFactory.click(x: "1", y: "2")
        let metadata = DexterActionRecoveryMetadataBuilder.build(
            action: clickAction,
            observationBefore: before,
            observationAfter: before
        )

        let recoveryKind = DexterActionVerificationRecoveryPolicy.recoveryKindAfterVerificationFailure(
            action: clickAction,
            metadata: metadata
        )
        #expect(recoveryKind == .none)
    }

    @Test func verificationRecoveryAllowsSingleNavigationRetry() {
        let before = DexterActionObservationSnapshot.empty
        let openAction = DexterActionFactory.openApplication(named: "Safari")
        let metadata = DexterActionRecoveryMetadataBuilder.build(
            action: openAction,
            observationBefore: before,
            observationAfter: before
        )

        #expect(
            DexterActionVerificationRecoveryPolicy.shouldRetrySameActionAfterVerificationFailure(
                action: openAction,
                metadata: metadata,
                didAlreadyAttemptRecovery: false
            )
        )
        #expect(
            !DexterActionVerificationRecoveryPolicy.shouldRetrySameActionAfterVerificationFailure(
                action: openAction,
                metadata: metadata,
                didAlreadyAttemptRecovery: true
            )
        )
    }

    @Test func ledgerRecordsOnlyCompletedReversibleUndo() {
        let ledger = DexterActionRecoveryLedger()
        let before = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeApplicationLocalizedName: "Safari",
            activeWindowTitle: nil,
            pointerElementTitle: nil,
            pointerElementRoleDescription: nil,
            pointerElementValueDescription: nil,
            browserState: .empty,
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let action = DexterActionFactory.openApplication(named: "Calculator").withState(.completed)
        let metadata = DexterActionRecoveryMetadataBuilder.build(
            action: action,
            observationBefore: before,
            observationAfter: before
        )

        ledger.recordCompletedAction(metadata: metadata, action: action)
        #expect(ledger.latestUndoableEntry() != nil)
        #expect(DexterActionRecoveryIntentRecognizer.recognizeUndo(fromUserMessage: "undo last safe action"))
    }
}

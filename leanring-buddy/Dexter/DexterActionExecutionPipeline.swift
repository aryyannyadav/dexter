//
//  DexterActionExecutionPipeline.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

struct DexterActionExecutionOutcome: Equatable {
    let action: DexterAction
    let spokenSummary: String
    /// When set, the orchestrator should surface confirmation UI before continuing.
    let pendingConfirmation: DexterPendingActionExecution?
    let verificationReport: DexterActionVerificationReport?
}

enum DexterActionExecutionPipeline {
    @MainActor
    static func execute(
        proposedAction: DexterAction,
        context: DexterContext,
        permissionManager: PermissionManager,
        contextObserver: DexterActionContextObserver,
        agentRuntime: AgentRuntime,
        actionVerifier: ActionVerifier,
        actionStore: DexterActionStore,
        actionHistoryStore: DexterActionHistoryStore,
        actionPermissionSettings: DexterActionPermissionSettings,
        hasPersistedScreenContentGrant: Bool,
        confirmationGrant: DexterActionConfirmationGrant? = nil,
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil
    ) async -> DexterActionExecutionOutcome {
        var action = proposedAction.withState(.proposed)
        actionStore.register(action)

        let resolvedRiskLevel = DexterActionRiskClassifier.resolvedRiskLevel(for: action)
        if resolvedRiskLevel == .readOnly {
            action = action.withState(.completed)
            actionStore.update(action)
            let summary = "Dexter inspected the current context without making changes: \(action.humanReadableDescription)"
            return DexterActionExecutionOutcome(action: action, spokenSummary: summary, pendingConfirmation: nil, verificationReport: nil)
        }

        if DexterActionConfirmationPolicy.requiresUserConfirmation(
            action: action,
            settings: actionPermissionSettings,
            confirmationGrant: confirmationGrant
        ) {
            action = action.withState(.awaitingConfirmation)
            actionStore.update(action)
            let confirmationContent = DexterActionConfirmationContentBuilder.build(action: action, context: context)
            let pending = DexterPendingActionExecution(
                action: action,
                context: context,
                hasPersistedScreenContentGrant: hasPersistedScreenContentGrant,
                confirmationContent: confirmationContent
            )
            let message = DexterActionConfirmationPolicy.spokenSummaryWhenAwaitingConfirmation(confirmationContent)
            demonstrationPhaseStore?.transition(
                to: .waitingForApproval,
                detail: action.humanReadableDescription
            )
            return DexterActionExecutionOutcome(action: action, spokenSummary: message, pendingConfirmation: pending, verificationReport: nil)
        }

        let permissionDecision = permissionManager.evaluateComputerActionPermission(
            action,
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
        )
        guard permissionDecision.isAllowed else {
            action = action.withState(.failed)
            actionStore.update(action)
            actionHistoryStore.recordAction(actionIdentifier: action.type.rawValue, summary: permissionDecision.message)
            demonstrationPhaseStore?.transition(to: .done, detail: permissionDecision.message)
            return DexterActionExecutionOutcome(action: action, spokenSummary: permissionDecision.message, pendingConfirmation: nil, verificationReport: nil)
        }

        action = action.withState(.approved)
        actionStore.update(action)

        action = action.withState(.executing)
        actionStore.update(action)

        demonstrationPhaseStore?.transition(to: .acting, detail: action.humanReadableDescription)

        let observationBefore = DexterActionObservationSnapshot.from(context: context)
        let agentRequest = DexterActionAgentRequestMapper.agentActionRequest(for: action)

        do {
            let verificationBundle = try await executeObserveVerifyReport(
                action: action,
                agentRequest: agentRequest,
                observationBefore: observationBefore,
                context: context,
                hasPersistedScreenContentGrant: hasPersistedScreenContentGrant,
                permissionManager: permissionManager,
                contextObserver: contextObserver,
                agentRuntime: agentRuntime,
                actionVerifier: actionVerifier,
                demonstrationPhaseStore: demonstrationPhaseStore
            )

            action = verificationBundle.updatedAction
            actionStore.update(action)
            actionHistoryStore.recordAction(
                actionIdentifier: action.type.rawValue,
                summary: verificationBundle.verificationOutcome.summary
            )
            demonstrationPhaseStore?.transition(
                to: .done,
                detail: verificationBundle.verificationOutcome.summary
            )
            return DexterActionExecutionOutcome(
                action: action,
                spokenSummary: verificationBundle.verificationOutcome.summary,
                pendingConfirmation: nil,
                verificationReport: verificationBundle.verificationOutcome.report
            )
        } catch is CancellationError {
            action = action.withState(.cancelled)
            actionStore.update(action)
            _ = await agentRuntime.cancelCurrentAction()
            let message = DexterUserFacingErrorMessage.forActionRuntimeError(CancellationError(), runtimeName: agentRuntime.runtimeName)
            actionHistoryStore.recordAction(actionIdentifier: action.type.rawValue, summary: message)
            demonstrationPhaseStore?.transition(to: .done, detail: message)
            return DexterActionExecutionOutcome(action: action, spokenSummary: message, pendingConfirmation: nil, verificationReport: nil)
        } catch {
            action = action.withState(.failed)
            actionStore.update(action)
            _ = await agentRuntime.cancelCurrentAction()
            let message = DexterUserFacingErrorMessage.forActionRuntimeError(error, runtimeName: agentRuntime.runtimeName)
            actionHistoryStore.recordAction(actionIdentifier: action.type.rawValue, summary: message)
            demonstrationPhaseStore?.transition(to: .done, detail: message)
            return DexterActionExecutionOutcome(action: action, spokenSummary: message, pendingConfirmation: nil, verificationReport: nil)
        }
    }

    @MainActor
    private static func executeObserveVerifyReport(
        action: DexterAction,
        agentRequest: AgentActionRequest,
        observationBefore: DexterActionObservationSnapshot,
        context: DexterContext,
        hasPersistedScreenContentGrant: Bool,
        permissionManager: PermissionManager,
        contextObserver: DexterActionContextObserver,
        agentRuntime: AgentRuntime,
        actionVerifier: ActionVerifier,
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil
    ) async throws -> (updatedAction: DexterAction, verificationOutcome: ActionVerificationOutcome) {
        var currentAction = action
        var didAttemptSafeRetry = false

        while true {
            try Task.checkCancellation()

            let executionResult = try await DexterAgentRuntimeExecutionGuard.executeAction(
                agentRuntime: agentRuntime,
                actionRequest: agentRequest
            )

            try Task.checkCancellation()

            demonstrationPhaseStore?.transition(to: .verifying, detail: "Comparing intended vs observed state")

            let permissionSnapshot = permissionManager.currentPermissionSnapshot(
                hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
            )
            let observationPointerLocation = DexterActionObservationPointerResolver.pointerLocationInScreenSpace(
                for: currentAction,
                context: context
            )
            let observationAfter = contextObserver.observeCurrentEnvironment(
                pointerLocationInScreenSpace: observationPointerLocation,
                hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission
            )

            let verificationOutcome = await actionVerifier.verify(
                action: currentAction,
                executionResult: executionResult,
                observationBefore: observationBefore,
                observationAfter: observationAfter
            )

            if verificationOutcome.status == .failed,
               !didAttemptSafeRetry,
               DexterActionSafeRetryPolicy.canAttemptSafeRetry(for: currentAction) {
                didAttemptSafeRetry = true
                continue
            }

            switch verificationOutcome.status {
            case .success:
                currentAction = currentAction.withState(.completed)
            case .failed:
                currentAction = currentAction.withState(.verificationFailed)
            case .uncertain:
                currentAction = currentAction.withState(.verificationFailed)
            }

            return (currentAction, verificationOutcome)
        }
    }
}

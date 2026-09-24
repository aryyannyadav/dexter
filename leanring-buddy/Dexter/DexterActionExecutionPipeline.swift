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
    let turnRecord: DexterActionTurnRecord?
    let executionSnapshot: DexterExecutionMachineSnapshot?
    let recoveryMetadata: DexterActionRecoveryMetadata?
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
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil,
        executionStateMachine: DexterExecutionStateMachine? = nil,
        executionStateMachineRegistry: DexterExecutionStateMachineRegistry? = nil,
        parentTaskIdentifier: UUID? = nil,
        actionRecoveryLedger: DexterActionRecoveryLedger? = nil
    ) async -> DexterActionExecutionOutcome {
        let stateMachine = executionStateMachine
            ?? DexterExecutionStateMachine(
                actionIdentifier: proposedAction.id,
                parentTaskIdentifier: parentTaskIdentifier
            )
        executionStateMachineRegistry?.register(stateMachine)

        var action = proposedAction.withState(.proposed)
        actionStore.register(action)

        let safetyEnvelope = DexterExecutionSafetyEnvelope.standard
        let safetyDecision = DexterExecutionSafetyGuard.evaluateBeforeExecution(
            action: action,
            envelope: safetyEnvelope,
            stateMachine: stateMachine,
            confirmationGrant: confirmationGrant,
            targetApplicationBundleIdentifier: context.activeApplication.bundleIdentifier
        )
        if !safetyDecision.isAllowed {
            return failOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                message: safetyDecision.userFacingMessage,
                machineError: .cancellationRequested
            )
        }

        DexterEmergencyStopController.shared.beginRunningAutomation()

        do {
            try stateMachine.checkContinuationAllowed()
            try DexterExecutionStateMachinePipelineSupport.ensurePlanningPhase(stateMachine)
        } catch let machineError as DexterExecutionStateMachineError {
            return failOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                message: DexterExecutionStateMachinePipelineSupport.userFacingMessage(for: machineError),
                machineError: machineError
            )
        } catch is CancellationError {
            return cancelOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                agentRuntime: agentRuntime,
                message: DexterUserFacingErrorMessage.forActionRuntimeError(
                    CancellationError(),
                    runtimeName: agentRuntime.runtimeName
                )
            )
        } catch {
            return failOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                message: DexterUserFacingErrorMessage.forActionRuntimeError(error, runtimeName: agentRuntime.runtimeName),
                machineError: nil
            )
        }

        let resolvedRiskLevel = DexterActionRiskClassifier.resolvedRiskLevel(for: action)
        if resolvedRiskLevel == .readOnly {
            action = action.withState(.completed)
            actionStore.update(action)
            let summary = "Dexter inspected the current context without making changes: \(action.humanReadableDescription)"
            do {
                try stateMachine.transition(to: .completed, progressSummary: summary)
            } catch {
                // Read-only completion should always be allowed from planning.
            }
            return DexterActionExecutionOutcome(
                action: action,
                spokenSummary: summary,
                pendingConfirmation: nil,
                verificationReport: nil,
                turnRecord: nil,
                executionSnapshot: stateMachine.snapshot,
                recoveryMetadata: nil
            )
        }

        let observationBeforeConfirmation = DexterActionObservationSnapshot.from(context: context)

        if DexterActionConfirmationPolicy.requiresUserConfirmation(
            action: action,
            settings: actionPermissionSettings,
            confirmationGrant: confirmationGrant,
            observationBefore: observationBeforeConfirmation
        ) {
            action = action.withState(.awaitingConfirmation)
            actionStore.update(action)
            let confirmationContent = DexterActionConfirmationContentBuilder.build(action: action, context: context)
            let pending = DexterPendingActionExecution(
                action: action,
                context: context,
                hasPersistedScreenContentGrant: hasPersistedScreenContentGrant,
                confirmationContent: confirmationContent,
                executionIdentifier: stateMachine.snapshot.executionIdentifier
            )
            let message = DexterActionConfirmationPolicy.spokenSummaryWhenAwaitingConfirmation(confirmationContent)
            demonstrationPhaseStore?.transition(
                to: DexterDemonstrationPhase.waitingForApproval,
                detail: action.humanReadableDescription
            )
            let agentRequestForOpenClawRouting = DexterActionAgentRequestMapper.agentActionRequest(for: action)
            if OpenClawRuntimeAllowlist.isDexterSupportedAction(agentRequestForOpenClawRouting) {
                DexterOpenClawLog.log("approval required")
            }
            do {
                try stateMachine.transition(to: .waitingPermission, progressSummary: "Waiting for your approval in the Dexter panel.")
            } catch {
                return failOutcome(
                    action: action,
                    stateMachine: stateMachine,
                    actionStore: actionStore,
                    message: DexterExecutionStateMachinePipelineSupport.userFacingMessage(for: error as? DexterExecutionStateMachineError ?? .invalidTransition(from: .planning, to: .waitingPermission)),
                    machineError: error as? DexterExecutionStateMachineError
                )
            }
            return DexterActionExecutionOutcome(
                action: action,
                spokenSummary: message,
                pendingConfirmation: pending,
                verificationReport: nil,
                turnRecord: nil,
                executionSnapshot: stateMachine.snapshot,
                recoveryMetadata: nil
            )
        }

        let permissionDecision = permissionManager.evaluateComputerActionPermission(
            action,
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
        )
        guard permissionDecision.isAllowed else {
            action = action.withState(.failed)
            actionStore.update(action)
            actionHistoryStore.recordAction(actionIdentifier: action.type.rawValue, summary: permissionDecision.message)
            DexterActionDiagnosticLog.permission("refused reason=\(permissionDecision.message)")
            DexterObservabilityLog.permission("outcome=PERMISSION_DENIED reason=\(permissionDecision.message)")
            do {
                try stateMachine.fail(code: "permission_denied", message: permissionDecision.message)
            } catch {
                // Permission refusal maps to FAILED from planning or waiting permission.
            }
            return DexterActionExecutionOutcome(
                action: action,
                spokenSummary: permissionDecision.message,
                pendingConfirmation: nil,
                verificationReport: nil,
                turnRecord: nil,
                executionSnapshot: stateMachine.snapshot,
                recoveryMetadata: nil
            )
        }

        action = action.withState(.approved)
        actionStore.update(action)

        do {
            try stateMachine.checkContinuationAllowed()
            let executingProgressSummary = action.humanReadableDescription
            if stateMachine.snapshot.currentPhase == .waitingPermission {
                try stateMachine.transition(to: .executing, progressSummary: executingProgressSummary)
            } else {
                try stateMachine.transition(to: .executing, progressSummary: executingProgressSummary)
            }
            try stateMachine.recordActionConsumption()
            try stateMachine.recordToolConsumption()
        } catch let machineError as DexterExecutionStateMachineError {
            return failOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                message: DexterExecutionStateMachinePipelineSupport.userFacingMessage(for: machineError),
                machineError: machineError
            )
        } catch is CancellationError {
            return cancelOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                agentRuntime: agentRuntime,
                message: DexterUserFacingErrorMessage.forActionRuntimeError(
                    CancellationError(),
                    runtimeName: agentRuntime.runtimeName
                )
            )
        } catch {
            return failOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                message: DexterUserFacingErrorMessage.forActionRuntimeError(error, runtimeName: agentRuntime.runtimeName),
                machineError: nil
            )
        }

        action = action.withState(.executing)
        actionStore.update(action)

        demonstrationPhaseStore?.transition(to: .acting, detail: action.humanReadableDescription)

        DexterActionDiagnosticLog.permission("approved")
        let agentRequest = DexterActionAgentRequestMapper.agentActionRequest(for: action)
        if let targetApplicationName = agentRequest.parameters["applicationName"] {
            DexterActionDiagnosticLog.intent("type=\(agentRequest.actionIdentifier) target=\(targetApplicationName)")
            DexterActionDiagnosticLog.plan("runtime=OpenClaw command=computer.act")
            DexterActionDiagnosticLog.action("id=\(action.id.uuidString.prefix(8)) intent=\(agentRequest.actionIdentifier) target=\(targetApplicationName)")
        }

        let observationBefore = DexterActionObservationSnapshot.from(context: context)

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
                demonstrationPhaseStore: demonstrationPhaseStore,
                executionStateMachine: stateMachine,
                actionRecoveryLedger: actionRecoveryLedger
            )

            action = verificationBundle.updatedAction
            actionStore.update(action)
            actionHistoryStore.recordAction(
                actionIdentifier: action.type.rawValue,
                summary: verificationBundle.verificationOutcome.summary
            )
            let turnRecord = DexterActionTurnRecordBuilder.build(
                action: action,
                runtimeName: agentRuntime.runtimeName,
                runtimeExecutionIdentifier: nil,
                verificationReport: verificationBundle.verificationOutcome.report,
                spokenSummary: verificationBundle.verificationOutcome.summary
            )
            DexterActionDiagnosticLog.action("completed status=\(turnRecord.resultStatus.rawValue)")
            try completeExecutionStateMachine(
                stateMachine: stateMachine,
                verificationOutcome: verificationBundle.verificationOutcome
            )

            return DexterActionExecutionOutcome(
                action: action,
                spokenSummary: verificationBundle.verificationOutcome.summary,
                pendingConfirmation: nil,
                verificationReport: verificationBundle.verificationOutcome.report,
                turnRecord: turnRecord,
                executionSnapshot: stateMachine.snapshot,
                recoveryMetadata: verificationBundle.recoveryMetadata
            )
        } catch is CancellationError {
            _ = await agentRuntime.cancelCurrentAction()
            return cancelOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                agentRuntime: agentRuntime,
                actionHistoryStore: actionHistoryStore,
                demonstrationPhaseStore: demonstrationPhaseStore,
                message: DexterUserFacingErrorMessage.forActionRuntimeError(
                    CancellationError(),
                    runtimeName: agentRuntime.runtimeName
                )
            )
        } catch let machineError as DexterExecutionStateMachineError {
            _ = await agentRuntime.cancelCurrentAction()
            return failOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                actionHistoryStore: actionHistoryStore,
                demonstrationPhaseStore: demonstrationPhaseStore,
                message: DexterExecutionStateMachinePipelineSupport.userFacingMessage(for: machineError),
                machineError: machineError
            )
        } catch {
            _ = await agentRuntime.cancelCurrentAction()
            return failOutcome(
                action: action,
                stateMachine: stateMachine,
                actionStore: actionStore,
                actionHistoryStore: actionHistoryStore,
                demonstrationPhaseStore: demonstrationPhaseStore,
                message: DexterUserFacingErrorMessage.forActionRuntimeError(error, runtimeName: agentRuntime.runtimeName),
                machineError: nil
            )
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
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil,
        executionStateMachine: DexterExecutionStateMachine,
        actionRecoveryLedger: DexterActionRecoveryLedger? = nil
    ) async throws -> (
        updatedAction: DexterAction,
        verificationOutcome: ActionVerificationOutcome,
        recoveryMetadata: DexterActionRecoveryMetadata?
    ) {
        var currentAction = action
        var didAttemptSafeRetry = false

        while true {
            try Task.checkCancellation()
            try executionStateMachine.checkContinuationAllowed()

            DexterTaskTraceRecorder.shared.markPhase(.toolCalls)
            let executionResult = try await DexterAgentRuntimeExecutionGuard.executeAction(
                agentRuntime: agentRuntime,
                actionRequest: agentRequest
            )
            DexterTaskTraceRecorder.shared.markPhase(.executionResults)
            DexterObservabilityLog.tool("execution_result reportedSuccess=\(executionResult.reportedSuccess)")

            try Task.checkCancellation()

            if DexterActionVerificationEngine.requiresPostExecutionObservationSettle(for: currentAction) {
                try await Task.sleep(nanoseconds: 350_000_000)
            }

            try executionStateMachine.transition(to: .verifying, progressSummary: "Comparing intended vs observed state.")
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
            DexterTaskTraceRecorder.shared.markPhase(.observation)
            DexterObservabilityLog.observe("post_action_environment_snapshot collected")

            DexterActionDiagnosticLog.verify("verification started")

            let verificationOutcome = await DexterTaskTraceRecorder.shared.measure(bucket: .verification) {
                await actionVerifier.verify(
                action: currentAction,
                executionResult: executionResult,
                observationBefore: observationBefore,
                observationAfter: observationAfter
                )
            }

            switch verificationOutcome.status {
            case .verified:
                DexterActionDiagnosticLog.verify("verification result=verified")
            case .partiallyVerified:
                DexterActionDiagnosticLog.verify("verification result=partiallyVerified")
            case .unavailable:
                DexterActionDiagnosticLog.verify("verification result=unavailable")
            case .failed:
                DexterActionDiagnosticLog.verify("verification result=failed")
                DexterObservabilityLog.verify("outcome=VERIFICATION_FAILED action=\(currentAction.type.rawValue)")
            }

            let recoveryMetadata = DexterActionRecoveryMetadataBuilder.build(
                action: currentAction,
                observationBefore: observationBefore,
                observationAfter: observationAfter
            )

            if verificationOutcome.status == .failed,
               DexterActionVerificationRecoveryPolicy.shouldRetrySameActionAfterVerificationFailure(
                   action: currentAction,
                   metadata: recoveryMetadata,
                   didAlreadyAttemptRecovery: didAttemptSafeRetry
               ) {
                didAttemptSafeRetry = true
                DexterObservabilityLog.verify("explicit_recovery=retry_same_low_risk_navigation_once")
                continue
            }

            switch verificationOutcome.status {
            case .verified, .partiallyVerified:
                currentAction = currentAction.withState(.completed)
                actionRecoveryLedger?.recordCompletedAction(
                    metadata: recoveryMetadata,
                    action: currentAction
                )
            case .unavailable, .failed:
                currentAction = currentAction.withState(.verificationFailed)
            }

            let metadataToReturn: DexterActionRecoveryMetadata? =
                currentAction.state == .completed ? recoveryMetadata : nil

            return (currentAction, verificationOutcome, metadataToReturn)
        }
    }

    @MainActor
    private static func completeExecutionStateMachine(
        stateMachine: DexterExecutionStateMachine,
        verificationOutcome: ActionVerificationOutcome
    ) throws {
        switch verificationOutcome.status {
        case .verified, .partiallyVerified:
            try stateMachine.transition(
                to: .completed,
                progressSummary: verificationOutcome.summary,
                verificationStatus: verificationOutcome.status
            )
        case .unavailable, .failed:
            try stateMachine.fail(code: "verification_failed", message: verificationOutcome.summary)
        }
    }

    @MainActor
    private static func failOutcome(
        action: DexterAction,
        stateMachine: DexterExecutionStateMachine,
        actionStore: DexterActionStore,
        actionHistoryStore: DexterActionHistoryStore? = nil,
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil,
        message: String,
        machineError: DexterExecutionStateMachineError?
    ) -> DexterActionExecutionOutcome {
        var failedAction = action.withState(.failed)
        actionStore.update(failedAction)
        actionHistoryStore?.recordAction(actionIdentifier: failedAction.type.rawValue, summary: message)
        if let machineError {
            let code = DexterExecutionStateMachinePipelineSupport.failCode(for: machineError)
            try? stateMachine.fail(code: code, message: message)
        } else if !stateMachine.snapshot.currentPhase.isTerminal {
            try? stateMachine.fail(code: "execution_failed", message: message)
        }

        return DexterActionExecutionOutcome(
            action: failedAction,
            spokenSummary: message,
            pendingConfirmation: nil,
            verificationReport: nil,
            turnRecord: nil,
            executionSnapshot: stateMachine.snapshot,
            recoveryMetadata: nil
        )
    }

    @MainActor
    private static func cancelOutcome(
        action: DexterAction,
        stateMachine: DexterExecutionStateMachine,
        actionStore: DexterActionStore,
        agentRuntime: AgentRuntime,
        actionHistoryStore: DexterActionHistoryStore? = nil,
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil,
        message: String
    ) -> DexterActionExecutionOutcome {
        var cancelledAction = action.withState(.cancelled)
        actionStore.update(cancelledAction)
        actionHistoryStore?.recordAction(actionIdentifier: cancelledAction.type.rawValue, summary: message)
        try? stateMachine.cancel(message: message)

        return DexterActionExecutionOutcome(
            action: cancelledAction,
            spokenSummary: message,
            pendingConfirmation: nil,
            verificationReport: nil,
            turnRecord: nil,
            executionSnapshot: stateMachine.snapshot,
            recoveryMetadata: nil
        )
    }
}

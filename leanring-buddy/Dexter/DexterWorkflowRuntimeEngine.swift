//
//  DexterWorkflowRuntimeEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterWorkflowRuntimeEngine {
    static func shouldCancelWorkflow(forUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased()
        return normalized.contains("cancel workflow")
            || normalized.contains("stop workflow")
            || normalized.contains("cancel this workflow")
    }

    static func userContinuesWorkflow(forUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let phrases = ["continue", "next", "ready", "done", "ok", "okay", "proceed", "yes"]
        return phrases.contains { normalized == $0 || normalized.hasPrefix("\($0) ") }
    }

    static func shouldProceedWithStep(userMessage: String, workflow: DexterLearnedWorkflow) -> Bool {
        if userContinuesWorkflow(forUserMessage: userMessage) {
            return true
        }
        return DexterWorkflowCatalog.workflowMatchingTrigger(userMessage: userMessage)?.workflowIdentifier
            == workflow.workflowIdentifier
    }

    static func processTurn(
        userMessage: String,
        workflow: DexterLearnedWorkflow,
        session: DexterWorkflowRunSession,
        context: DexterContext,
        executeVerifiedAction: (DexterAction) async -> DexterActionExecutionOutcome
    ) async -> DexterWorkflowTurnOutcome {
        var updatedSession = session

        if shouldCancelWorkflow(forUserMessage: userMessage) {
            updatedSession.runtimePhase = .cancelled
            updatedSession.updatedAt = Date()
            return DexterWorkflowTurnOutcome(
                session: updatedSession,
                spokenSummary: "Cancelled “\(workflow.name)”.",
                didHandleTurn: true,
                requiresFreshContextOnNextTurn: false
            )
        }

        if updatedSession.isTerminal {
            return DexterWorkflowTurnOutcome(
                session: updatedSession,
                spokenSummary: "Workflow “\(workflow.name)” is already finished.",
                didHandleTurn: true,
                requiresFreshContextOnNextTurn: false
            )
        }

        guard workflow.steps.indices.contains(updatedSession.currentStepIndex) else {
            updatedSession.runtimePhase = .completed
            updatedSession.updatedAt = Date()
            return DexterWorkflowTurnOutcome(
                session: updatedSession,
                spokenSummary: "“\(workflow.name)” is complete.",
                didHandleTurn: true,
                requiresFreshContextOnNextTurn: false
            )
        }

        let currentStep = workflow.steps[updatedSession.currentStepIndex]

        updatedSession.runtimePhase = .condition
        guard evaluateConditions(workflow.conditions) else {
            updatedSession.runtimePhase = .failed
            return outcome(
                session: updatedSession,
                summary: "This workflow cannot run because the agent runtime is not available.",
                requiresFreshContext: false
            )
        }

        updatedSession.runtimePhase = .context
        let contextCheck = DexterWorkflowStepPlanner.contextMeetsRequirements(step: currentStep, context: context)
        if !contextCheck.isSatisfied, let missing = contextCheck.missingDescription {
            updatedSession.runtimePhase = .waitingForUser
            return outcome(
                session: updatedSession,
                summary: missing,
                requiresFreshContext: true
            )
        }

        updatedSession.runtimePhase = .plan
        let planOutcome = DexterWorkflowStepPlanner.plan(step: currentStep, workflow: workflow, context: context)

        switch planOutcome {
        case .waitForUser(let instruction):
            if !shouldProceedWithStep(userMessage: userMessage, workflow: workflow) {
                updatedSession.runtimePhase = .waitingForUser
                return outcome(
                    session: updatedSession,
                    summary: "\(workflow.name) — \(currentStep.title): \(instruction)",
                    requiresFreshContext: true
                )
            }
            return advanceAfterSuccessfulStep(
                workflow: workflow,
                session: updatedSession,
                step: currentStep,
                verificationMessage: "Confirmed."
            )

        case .askUser(let prompt):
            if !shouldProceedWithStep(userMessage: userMessage, workflow: workflow) {
                updatedSession.runtimePhase = .waitingForUser
                return outcome(
                    session: updatedSession,
                    summary: "I’m not certain enough to continue automatically. \(prompt)",
                    requiresFreshContext: true
                )
            }
            return advanceAfterSuccessfulStep(
                workflow: workflow,
                session: updatedSession,
                step: currentStep,
                verificationMessage: "Thanks — noted."
            )

        case .failed(let reason):
            updatedSession.runtimePhase = .failed
            return outcome(session: updatedSession, summary: reason, requiresFreshContext: false)

        case .planned(let action):
            if currentStep.actionKind != .waitForUserConfirmation,
               !shouldProceedWithStep(userMessage: userMessage, workflow: workflow) {
                updatedSession.runtimePhase = .permission
                return outcome(
                    session: updatedSession,
                    summary: "\(workflow.name) — \(currentStep.title): \(currentStep.instruction) Say “continue” to run this step with freshly gathered context.",
                    requiresFreshContext: true
                )
            }

            let linkedSkill = DexterSkillCatalog.allSkills().first {
                $0.workflow.workflowIdentifier == workflow.workflowIdentifier
            }

            let automationRequest = DexterSkillAutomationRuntime.buildWorkflowStepRequest(
                workflow: workflow,
                step: currentStep,
                userMessage: userMessage,
                context: context,
                proposedAction: action,
                linkedSkill: linkedSkill
            )
            let automationPlan = DexterSkillAutomationRuntime.plan(request: automationRequest)
            updatedSession.runtimePhase = .action

            let automationRunOutcome = await DexterSkillAutomationRuntime.execute(
                request: automationRequest,
                plan: automationPlan,
                executeVerifiedAction: executeVerifiedAction
            )
            let actionOutcome = automationRunOutcome.actionOutcome
                ?? DexterActionExecutionOutcome(
                    action: action.withState(.failed),
                    spokenSummary: automationRunOutcome.stoppedReason ?? "Workflow step did not run.",
                    pendingConfirmation: nil,
                    verificationReport: nil,
                    turnRecord: nil,
                    executionSnapshot: nil,
                    recoveryMetadata: nil
                )

            updatedSession.runtimePhase = .verify
            let verificationPassed = verifyStep(
                step: currentStep,
                actionOutcome: actionOutcome,
                context: context
            )

            if !verificationPassed {
                updatedSession.runtimePhase = .waitingForUser
                return outcome(
                    session: updatedSession,
                    summary: "Step “\(currentStep.title)” did not verify cleanly: \(actionOutcome.spokenSummary) I stopped — tell me what you see or say “continue” to retry after fixing the environment.",
                    requiresFreshContext: true
                )
            }

            return advanceAfterSuccessfulStep(
                workflow: workflow,
                session: updatedSession,
                step: currentStep,
                verificationMessage: actionOutcome.spokenSummary
            )
        }
    }

    private static func evaluateConditions(_ conditions: [DexterWorkflowCondition]) -> Bool {
        for condition in conditions {
            switch condition.kind {
            case "agent_runtime_available":
                if !DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled {
                    return false
                }
            default:
                break
            }
        }
        return true
    }

    private static func verifyStep(
        step: DexterWorkflowStepDefinition,
        actionOutcome: DexterActionExecutionOutcome,
        context: DexterContext
    ) -> Bool {
        guard let verification = step.verification else {
            return actionOutcome.action.state == .completed
        }

        switch verification.strategy {
        case "user_confirmed":
            return true
        case "application_running":
            return actionOutcome.action.state == .completed
        case "terminal_output_nonempty":
            return actionOutcome.action.state == .completed
        case "browser_url_contains":
            return actionOutcome.action.state == .completed
        case "action_verified":
            return actionOutcome.action.state == .completed
        default:
            return actionOutcome.action.state == .completed
        }
    }

    private static func advanceAfterSuccessfulStep(
        workflow: DexterLearnedWorkflow,
        session: DexterWorkflowRunSession,
        step: DexterWorkflowStepDefinition,
        verificationMessage: String
    ) -> DexterWorkflowTurnOutcome {
        var updatedSession = session
        updatedSession.runtimePhase = .nextStep
        updatedSession.currentStepIndex += 1
        updatedSession.updatedAt = Date()

        if updatedSession.currentStepIndex >= workflow.steps.count {
            updatedSession.runtimePhase = .completed
            return DexterWorkflowTurnOutcome(
                session: updatedSession,
                spokenSummary: "“\(workflow.name)” finished. \(verificationMessage)",
                didHandleTurn: true,
                requiresFreshContextOnNextTurn: false
            )
        }

        let nextStep = workflow.steps[updatedSession.currentStepIndex]
        updatedSession.runtimePhase = .waitingForUser
        return DexterWorkflowTurnOutcome(
            session: updatedSession,
            spokenSummary: "Step “\(step.title)” done. Next — \(nextStep.title): \(nextStep.instruction)",
            didHandleTurn: true,
            requiresFreshContextOnNextTurn: true
        )
    }

    private static func outcome(
        session: DexterWorkflowRunSession,
        summary: String,
        requiresFreshContext: Bool
    ) -> DexterWorkflowTurnOutcome {
        var mutableSession = session
        mutableSession.updatedAt = Date()
        return DexterWorkflowTurnOutcome(
            session: mutableSession,
            spokenSummary: summary,
            didHandleTurn: true,
            requiresFreshContextOnNextTurn: requiresFreshContext
        )
    }
}

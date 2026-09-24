//
//  DexterSkillAutomationRuntime.swift
//  leanring-buddy
//
//  Single runtime for skills, workflows, and proactive automations.
//  Skill → Trigger → Context → Intent → Plan → Policy → Tool Gateway → Execute → Verify → Memory
//

import Foundation

enum DexterSkillAutomationRuntimeLog {
    static func log(phase: DexterSkillPipelinePhase, detail: String? = nil) {
        if let detail, !detail.isEmpty {
            print("[DEXTER][SKILL_RUNTIME] \(phase.rawValue) \(detail)")
        } else {
            print("[DEXTER][SKILL_RUNTIME] \(phase.rawValue)")
        }
    }
}

struct DexterSkillAutomationRunRequest: Equatable {
    let trigger: DexterAutomationTrigger
    let envelope: DexterAutomationEnvelope
    let context: DexterContext
    let skill: DexterSkill?
    let skillEngineResult: DexterSkillEngineResult?
    let intentEngineResult: DexterIntentEngineResult?
    let proactiveEvent: DexterProactiveEvent?
    let automationRegistration: DexterProactiveAutomationRegistration?
    let userGrantedAutonomousExecution: Bool
    let workflow: DexterLearnedWorkflow?
    let workflowStep: DexterWorkflowStepDefinition?
    let preplannedAction: DexterAction?
}

struct DexterSkillAutomationPlan: Equatable {
    let envelope: DexterAutomationEnvelope
    let pipelinePhases: [DexterSkillPipelinePhase]
    let completedPhases: [DexterSkillPipelinePhase]
    let mergedIntentPlan: DexterIntentPlan?
    let proactivePolicyDecision: DexterProactivePolicyDecision?
    let proposedAction: DexterAction?
    let shouldExecuteAction: Bool
    let userFacingSummary: String
}

struct DexterSkillAutomationRunOutcome: Equatable {
    let plan: DexterSkillAutomationPlan
    let actionOutcome: DexterActionExecutionOutcome?
    let verificationSummary: String?
    let stoppedReason: String?
}

enum DexterSkillAutomationRuntime {
    static let canonicalPipelinePhases: [DexterSkillPipelinePhase] = [
        .skill,
        .trigger,
        .context,
        .intent,
        .plan,
        .policy,
        .toolGateway,
        .execute,
        .verify,
        .memory
    ]

    static func buildManualRequest(
        userMessage: String,
        context: DexterContext,
        skillEngineResult: DexterSkillEngineResult,
        intentEngineResult: DexterIntentEngineResult
    ) -> DexterSkillAutomationRunRequest {
        DexterSkillAutomationRunRequest(
            trigger: .manualInvocation(userMessage: userMessage),
            envelope: DexterAutomationEnvelope.forManualTurn(
                userMessage: userMessage,
                skill: skillEngineResult.matchedSkill
            ),
            context: context,
            skill: skillEngineResult.matchedSkill,
            skillEngineResult: skillEngineResult,
            intentEngineResult: intentEngineResult,
            proactiveEvent: nil,
            automationRegistration: nil,
            userGrantedAutonomousExecution: false,
            workflow: nil,
            workflowStep: nil,
            preplannedAction: nil
        )
    }

    static func buildProactiveRequest(
        event: DexterProactiveEvent,
        context: DexterContext,
        automationRegistration: DexterProactiveAutomationRegistration?,
        userGrantedAutonomousExecution: Bool
    ) -> DexterSkillAutomationRunRequest {
        let limits = automationRegistration?.limits ?? DexterProactiveAutomationLimits.conservativeDefault
        let linkedSkill = automationRegistration?.linkedWorkflowIdentifier.flatMap { workflowIdentifier in
            DexterSkillCatalog.allSkills().first { $0.workflow.workflowIdentifier == workflowIdentifier }
        }

        return DexterSkillAutomationRunRequest(
            trigger: .event(event),
            envelope: DexterAutomationEnvelope.forProactiveEvent(event, limits: limits),
            context: context,
            skill: linkedSkill,
            skillEngineResult: nil,
            intentEngineResult: nil,
            proactiveEvent: event,
            automationRegistration: automationRegistration,
            userGrantedAutonomousExecution: userGrantedAutonomousExecution,
            workflow: nil,
            workflowStep: nil,
            preplannedAction: nil
        )
    }

    static func buildWorkflowStepRequest(
        workflow: DexterLearnedWorkflow,
        step: DexterWorkflowStepDefinition,
        userMessage: String,
        context: DexterContext,
        proposedAction: DexterAction,
        linkedSkill: DexterSkill?
    ) -> DexterSkillAutomationRunRequest {
        DexterSkillAutomationRunRequest(
            trigger: .manualInvocation(userMessage: userMessage),
            envelope: DexterAutomationEnvelope.forWorkflow(workflow),
            context: context,
            skill: linkedSkill,
            skillEngineResult: nil,
            intentEngineResult: nil,
            proactiveEvent: nil,
            automationRegistration: nil,
            userGrantedAutonomousExecution: false,
            workflow: workflow,
            workflowStep: step,
            preplannedAction: proposedAction
        )
    }

    static func plan(request: DexterSkillAutomationRunRequest) -> DexterSkillAutomationPlan {
        var completedPhases: [DexterSkillPipelinePhase] = []

        if request.skill != nil {
            completedPhases.append(.skill)
            DexterSkillAutomationRuntimeLog.log(phase: .skill, detail: request.skill?.id.rawValue)
        }

        completedPhases.append(.trigger)
        DexterSkillAutomationRuntimeLog.log(phase: .trigger, detail: request.trigger.kind.rawValue)

        completedPhases.append(.context)
        DexterSkillAutomationRuntimeLog.log(phase: .context)

        if request.intentEngineResult != nil || request.skillEngineResult != nil {
            completedPhases.append(.intent)
            DexterSkillAutomationRuntimeLog.log(phase: .intent)
        }

        completedPhases.append(.plan)
        DexterSkillAutomationRuntimeLog.log(phase: .plan, detail: request.envelope.goal)

        let mergedIntentPlan = request.skillEngineResult?.mergedIntentPlan ?? request.intentEngineResult?.plan

        var proactivePolicyDecision: DexterProactivePolicyDecision?
        var proposedAction = request.preplannedAction
        var shouldExecuteAction = false
        var userFacingSummary = "Planned: \(request.envelope.goal)"

        if let event = request.proactiveEvent {
            proposedAction = proposedAction ?? DexterProactiveAgentBridge.proposeAction(
                for: event,
                context: request.context,
                automationRegistration: request.automationRegistration
            )

            proactivePolicyDecision = DexterProactivePolicyEngine.evaluate(
                event: event,
                automationRegistration: request.automationRegistration,
                isGlobalComputerControlAvailable: DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled,
                userGrantedProactiveExecution: request.userGrantedAutonomousExecution
            )

            completedPhases.append(.policy)
            DexterSkillAutomationRuntimeLog.log(phase: .policy, detail: proactivePolicyDecision?.mode.rawValue)

            userFacingSummary = proactivePolicyDecision?.explanation ?? userFacingSummary
            if let suggestion = proactivePolicyDecision?.suggestion {
                userFacingSummary += " \(suggestion)"
            }

            shouldExecuteAction = proactivePolicyDecision?.mode == .executeAutonomously
                && proposedAction != nil
                && request.automationRegistration?.limits != nil
        } else if request.preplannedAction != nil {
            completedPhases.append(.policy)
            DexterSkillAutomationRuntimeLog.log(phase: .policy, detail: "workflow_step")
            shouldExecuteAction = true
            userFacingSummary = request.workflowStep.map { "\(request.workflow?.name ?? "Workflow") — \($0.title)" } ?? userFacingSummary
        } else {
            completedPhases.append(.policy)
            DexterSkillAutomationRuntimeLog.log(phase: .policy, detail: "manual_turn")
        }

        if proposedAction != nil {
            completedPhases.append(.toolGateway)
            DexterSkillAutomationRuntimeLog.log(phase: .toolGateway)
        }

        return DexterSkillAutomationPlan(
            envelope: request.envelope,
            pipelinePhases: canonicalPipelinePhases,
            completedPhases: completedPhases,
            mergedIntentPlan: mergedIntentPlan,
            proactivePolicyDecision: proactivePolicyDecision,
            proposedAction: proposedAction,
            shouldExecuteAction: shouldExecuteAction,
            userFacingSummary: userFacingSummary
        )
    }

    @MainActor
    static func execute(
        request: DexterSkillAutomationRunRequest,
        plan: DexterSkillAutomationPlan,
        executeVerifiedAction: (DexterAction) async -> DexterActionExecutionOutcome
    ) async -> DexterSkillAutomationRunOutcome {
        guard plan.shouldExecuteAction, let proposedAction = plan.proposedAction else {
            return DexterSkillAutomationRunOutcome(
                plan: plan,
                actionOutcome: nil,
                verificationSummary: nil,
                stoppedReason: nil
            )
        }

        let startTime = Date()
        let bundleIdentifier = request.proactiveEvent?.metadata["bundle_identifier"]
            ?? request.context.activeApplication.bundleIdentifier
        let requestedPermissions = request.automationRegistration?.limits.allowedPermissions
            ?? request.workflowStep?.requiredPermissions
            ?? plan.envelope.permissionLimit

        guard DexterAutomationEnvelopePolicy.isWithinEnvelope(
            envelope: plan.envelope,
            elapsedSeconds: 0,
            actionCount: 1,
            requestedPermissions: requestedPermissions,
            targetApplicationBundleIdentifier: bundleIdentifier
        ) else {
            var stoppedPlan = plan
            stoppedPlan = DexterSkillAutomationPlan(
                envelope: plan.envelope,
                pipelinePhases: plan.pipelinePhases,
                completedPhases: plan.completedPhases,
                mergedIntentPlan: plan.mergedIntentPlan,
                proactivePolicyDecision: plan.proactivePolicyDecision,
                proposedAction: plan.proposedAction,
                shouldExecuteAction: false,
                userFacingSummary: plan.userFacingSummary + " Stopped: automation limits would be exceeded."
            )
            return DexterSkillAutomationRunOutcome(
                plan: stoppedPlan,
                actionOutcome: nil,
                verificationSummary: "Stopped: automation limits would be exceeded.",
                stoppedReason: "budget_exceeded"
            )
        }

        var completedPhases = plan.completedPhases
        completedPhases.append(.execute)
        DexterSkillAutomationRuntimeLog.log(phase: .execute)

        let actionOutcome = await executeVerifiedAction(proposedAction)

        completedPhases.append(.verify)
        DexterSkillAutomationRuntimeLog.log(phase: .verify)

        let elapsed = Date().timeIntervalSince(startTime)
        let withinLimits = DexterAutomationEnvelopePolicy.isWithinEnvelope(
            envelope: plan.envelope,
            elapsedSeconds: elapsed,
            actionCount: 1,
            requestedPermissions: requestedPermissions,
            targetApplicationBundleIdentifier: bundleIdentifier
        )

        let verified = actionOutcome.action.state == .completed && withinLimits
        let verificationSummary = verified
            ? actionOutcome.spokenSummary
            : "Verification uncertain: \(actionOutcome.spokenSummary)"

        completedPhases.append(.memory)
        DexterSkillAutomationRuntimeLog.log(phase: .memory, detail: "recorded_turn_outcome")

        let finalPlan = DexterSkillAutomationPlan(
            envelope: plan.envelope,
            pipelinePhases: plan.pipelinePhases,
            completedPhases: completedPhases,
            mergedIntentPlan: plan.mergedIntentPlan,
            proactivePolicyDecision: plan.proactivePolicyDecision,
            proposedAction: plan.proposedAction,
            shouldExecuteAction: plan.shouldExecuteAction,
            userFacingSummary: plan.userFacingSummary
        )

        return DexterSkillAutomationRunOutcome(
            plan: finalPlan,
            actionOutcome: actionOutcome,
            verificationSummary: verificationSummary,
            stoppedReason: verified ? nil : "verification_failed"
        )
    }

    static func proactivePhases(from skillPhases: [DexterSkillPipelinePhase]) -> [DexterProactivePipelinePhase] {
        var proactivePhases: [DexterProactivePipelinePhase] = []
        if skillPhases.contains(.trigger) || skillPhases.contains(.skill) {
            proactivePhases.append(.event)
        }
        if skillPhases.contains(.context) {
            proactivePhases.append(.context)
        }
        if skillPhases.contains(.policy) {
            proactivePhases.append(.policy)
        }
        if skillPhases.contains(.plan) || skillPhases.contains(.toolGateway) {
            proactivePhases.append(.agent)
        }
        if skillPhases.contains(.execute) {
            proactivePhases.append(.action)
        }
        if skillPhases.contains(.verify) {
            proactivePhases.append(.verification)
        }
        return proactivePhases
    }
}

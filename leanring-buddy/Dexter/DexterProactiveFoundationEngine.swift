//
//  DexterProactiveFoundationEngine.swift
//  leanring-buddy
//
//  Thin facade over DexterSkillAutomationRuntime for proactive events.
//

import Foundation

enum DexterProactiveFoundationLog {
    static func log(phase: DexterProactivePipelinePhase, detail: String? = nil) {
        if let detail, !detail.isEmpty {
            print("[DEXTER][PROACTIVE] \(phase.rawValue) \(detail)")
        } else {
            print("[DEXTER][PROACTIVE] \(phase.rawValue)")
        }
    }
}

enum DexterProactiveFoundationEngine {
    static func processEvent(
        event: DexterProactiveEvent,
        context: DexterContext,
        automationRegistrations: [DexterProactiveAutomationRegistration],
        userGrantedProactiveExecution: Bool = false,
        executeVerifiedAction: ((DexterAction) async -> DexterActionExecutionOutcome)? = nil
    ) async -> DexterProactivePipelineOutcome {
        let automationRegistration = DexterProactiveAutomationRegistry.registration(
            for: event.kind,
            in: automationRegistrations
        )

        let request = DexterSkillAutomationRuntime.buildProactiveRequest(
            event: event,
            context: context,
            automationRegistration: automationRegistration,
            userGrantedAutonomousExecution: userGrantedProactiveExecution
        )

        let plan = DexterSkillAutomationRuntime.plan(request: request)
        var completedPhases = DexterSkillAutomationRuntime.proactivePhases(from: plan.completedPhases)

        if plan.proactivePolicyDecision?.mode != .executeAutonomously {
            return DexterProactivePipelineOutcome(
                event: event,
                policyDecision: plan.proactivePolicyDecision ?? DexterProactivePolicyDecision(
                    mode: .suggest,
                    explanation: plan.userFacingSummary,
                    suggestion: nil,
                    permissionPrompt: nil,
                    stopOnUncertainty: true,
                    mayInvokeAgentRuntime: false
                ),
                proposedAction: plan.proposedAction,
                verificationSummary: nil,
                completedPhases: completedPhases
            )
        }

        guard let executeVerifiedAction else {
            let uncertainDecision = DexterProactivePolicyDecision(
                mode: .askPermission,
                explanation: plan.userFacingSummary,
                suggestion: plan.proactivePolicyDecision?.suggestion,
                permissionPrompt: "I'm not certain what action to take. Should Dexter proceed?",
                stopOnUncertainty: true,
                mayInvokeAgentRuntime: false
            )
            return DexterProactivePipelineOutcome(
                event: event,
                policyDecision: uncertainDecision,
                proposedAction: plan.proposedAction,
                verificationSummary: nil,
                completedPhases: completedPhases
            )
        }

        let runOutcome = await DexterSkillAutomationRuntime.execute(
            request: request,
            plan: plan,
            executeVerifiedAction: executeVerifiedAction
        )

        completedPhases = DexterSkillAutomationRuntime.proactivePhases(from: runOutcome.plan.completedPhases)

        return DexterProactivePipelineOutcome(
            event: event,
            policyDecision: runOutcome.plan.proactivePolicyDecision
                ?? plan.proactivePolicyDecision
                ?? DexterProactivePolicyDecision(
                    mode: .askPermission,
                    explanation: plan.userFacingSummary,
                    suggestion: nil,
                    permissionPrompt: nil,
                    stopOnUncertainty: true,
                    mayInvokeAgentRuntime: false
                ),
            proposedAction: runOutcome.plan.proposedAction,
            verificationSummary: runOutcome.verificationSummary,
            completedPhases: completedPhases
        )
    }

    static func userFacingMessage(for outcome: DexterProactivePipelineOutcome) -> String {
        var parts: [String] = [outcome.policyDecision.explanation]

        if let suggestion = outcome.policyDecision.suggestion {
            parts.append(suggestion)
        }

        if let permissionPrompt = outcome.policyDecision.permissionPrompt {
            parts.append(permissionPrompt)
        }

        if let verificationSummary = outcome.verificationSummary {
            parts.append(verificationSummary)
        }

        return parts.joined(separator: "\n\n")
    }

    static func detectAndProcessFirstEvent(
        detectionInput: DexterProactiveDetectionInput,
        context: DexterContext,
        automationRegistrations: [DexterProactiveAutomationRegistration],
        userGrantedProactiveExecution: Bool = false,
        executeVerifiedAction: ((DexterAction) async -> DexterActionExecutionOutcome)? = nil
    ) async -> DexterProactivePipelineOutcome? {
        guard let event = DexterProactiveEventDetector.detectEvents(from: detectionInput).first else {
            return nil
        }

        return await processEvent(
            event: event,
            context: context,
            automationRegistrations: automationRegistrations,
            userGrantedProactiveExecution: userGrantedProactiveExecution,
            executeVerifiedAction: executeVerifiedAction
        )
    }
}

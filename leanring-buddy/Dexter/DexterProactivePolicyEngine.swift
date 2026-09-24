//
//  DexterProactivePolicyEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterProactivePolicyEngine {
    /// Default path: detect → explain → suggest → ask permission. Autonomous execution only when explicitly enabled.
    static func evaluate(
        event: DexterProactiveEvent,
        automationRegistration: DexterProactiveAutomationRegistration?,
        isGlobalComputerControlAvailable: Bool,
        userGrantedProactiveExecution: Bool
    ) -> DexterProactivePolicyDecision {
        let explanation = "Detected \(event.kind.rawValue): \(event.title). \(event.detail)"
        let suggestion = suggestionForEvent(event)

        guard isGlobalComputerControlAvailable else {
            return DexterProactivePolicyDecision(
                mode: .detectAndExplain,
                explanation: explanation,
                suggestion: suggestion,
                permissionPrompt: nil,
                stopOnUncertainty: true,
                mayInvokeAgentRuntime: false
            )
        }

        let automationEnabled = automationRegistration?.isExplicitlyEnabledByUser == true

        if automationEnabled && userGrantedProactiveExecution {
            return DexterProactivePolicyDecision(
                mode: .executeAutonomously,
                explanation: explanation,
                suggestion: suggestion,
                permissionPrompt: nil,
                stopOnUncertainty: true,
                mayInvokeAgentRuntime: true
            )
        }

        if automationEnabled {
            return DexterProactivePolicyDecision(
                mode: .askPermission,
                explanation: explanation,
                suggestion: suggestion,
                permissionPrompt: permissionPrompt(for: event, limits: automationRegistration?.limits),
                stopOnUncertainty: true,
                mayInvokeAgentRuntime: false
            )
        }

        return DexterProactivePolicyDecision(
            mode: .suggest,
            explanation: explanation,
            suggestion: suggestion,
            permissionPrompt: "This automation is off by default. Enable it in Dexter settings if you want Dexter to act on \(event.kind.rawValue) without asking each time.",
            stopOnUncertainty: true,
            mayInvokeAgentRuntime: false
        )
    }

    static func shouldStopForUncertainty(policyDecision: DexterProactivePolicyDecision) -> Bool {
        policyDecision.stopOnUncertainty
    }

    static func isWithinLimits(
        limits: DexterProactiveAutomationLimits,
        elapsedSeconds: TimeInterval,
        actionCount: Int,
        requestedPermissions: [String],
        targetApplicationBundleIdentifier: String?
    ) -> Bool {
        let envelope = limits.asAutomationEnvelope(goal: "proactive_automation")
        return DexterAutomationEnvelopePolicy.isWithinEnvelope(
            envelope: envelope,
            elapsedSeconds: elapsedSeconds,
            actionCount: actionCount,
            requestedPermissions: requestedPermissions,
            targetApplicationBundleIdentifier: targetApplicationBundleIdentifier
        )
    }

    private static func suggestionForEvent(_ event: DexterProactiveEvent) -> String {
        switch event.kind {
        case .taskDeadlineApproaching:
            return "Review “\(event.title)” and update or complete the task if needed."
        case .newFile:
            return "Open or organize the new file if it relates to your current work."
        case .workflowRepetition:
            return "Consider saving this as a reusable workflow or running the prepared workflow template."
        case .applicationState:
            return "Switch back to your task context or confirm this app change was intentional."
        case .calendarEvent:
            return "Prepare for the upcoming calendar event using only what Dexter has on file."
        }
    }

    private static func permissionPrompt(
        for event: DexterProactiveEvent,
        limits: DexterProactiveAutomationLimits?
    ) -> String {
        let limitSummary = limits.map {
            "Limits: \(Int($0.maxDurationSeconds))s, \($0.maxActionCount) action(s), stop on uncertainty."
        } ?? "Limits: conservative defaults apply."
        return "Allow Dexter to run the proactive action for “\(event.title)”? \(limitSummary)"
    }
}

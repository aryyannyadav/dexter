//
//  DexterAutomationEnvelope.swift
//  leanring-buddy
//
//  Shared safety envelope for skills, workflows, and proactive automations.
//

import Foundation

struct DexterAutomationEnvelope: Equatable, Codable {
    var goal: String
    var timeLimitSeconds: TimeInterval
    var actionLimit: Int
    var permissionLimit: [String]
    var applicationScope: [String]
    var stopConditions: [String]

    static func forManualTurn(userMessage: String, skill: DexterSkill?) -> DexterAutomationEnvelope {
        let goal = skill.map { "\($0.name): \(userMessage)" } ?? userMessage
        let standard = DexterExecutionSafetyEnvelope.standard
        return DexterAutomationEnvelope(
            goal: goal,
            timeLimitSeconds: standard.timeoutSeconds,
            actionLimit: standard.maxActions,
            permissionLimit: skill?.permissions ?? standard.allowedPermissions,
            applicationScope: standard.allowedApplicationBundleIdentifiers,
            stopConditions: standard.stopConditions
        )
    }

    static func forWorkflow(_ workflow: DexterLearnedWorkflow) -> DexterAutomationEnvelope {
        DexterAutomationEnvelope(
            goal: workflow.name,
            timeLimitSeconds: 180,
            actionLimit: max(1, workflow.steps.count),
            permissionLimit: workflow.permissions,
            applicationScope: [],
            stopConditions: DexterExecutionSafetyEnvelope.standard.stopConditions
        )
    }

    static func forProactiveEvent(
        _ event: DexterProactiveEvent,
        limits: DexterProactiveAutomationLimits
    ) -> DexterAutomationEnvelope {
        DexterAutomationEnvelope(
            goal: "\(event.title) — \(event.detail)",
            timeLimitSeconds: limits.maxDurationSeconds,
            actionLimit: limits.maxActionCount,
            permissionLimit: limits.allowedPermissions,
            applicationScope: limits.allowedApplicationBundleIdentifiers,
            stopConditions: limits.stopConditions
        )
    }
}

extension DexterProactiveAutomationLimits {
    func asAutomationEnvelope(goal: String) -> DexterAutomationEnvelope {
        DexterAutomationEnvelope(
            goal: goal,
            timeLimitSeconds: maxDurationSeconds,
            actionLimit: maxActionCount,
            permissionLimit: allowedPermissions,
            applicationScope: allowedApplicationBundleIdentifiers,
            stopConditions: stopConditions
        )
    }
}

enum DexterAutomationEnvelopePolicy {
    static func isWithinEnvelope(
        envelope: DexterAutomationEnvelope,
        elapsedSeconds: TimeInterval,
        actionCount: Int,
        requestedPermissions: [String],
        targetApplicationBundleIdentifier: String?
    ) -> Bool {
        if elapsedSeconds > envelope.timeLimitSeconds {
            return false
        }
        if actionCount > envelope.actionLimit {
            return false
        }

        let safetyEnvelope = DexterExecutionSafetyEnvelope(
            permissionLevel: .explicitAutomationEnabled,
            maxSteps: envelope.actionLimit,
            maxToolCalls: envelope.actionLimit,
            maxActions: envelope.actionLimit,
            timeoutSeconds: envelope.timeLimitSeconds,
            allowedApplicationBundleIdentifiers: envelope.applicationScope,
            allowedPermissions: envelope.permissionLimit,
            stopConditions: envelope.stopConditions
        )

        if !DexterTrustSafetyPolicy.isApplicationInScope(
            envelope: safetyEnvelope,
            targetApplicationBundleIdentifier: targetApplicationBundleIdentifier
        ) {
            return false
        }

        if !DexterTrustSafetyPolicy.isPermissionInScope(
            envelope: safetyEnvelope,
            requestedPermissions: requestedPermissions
        ) {
            return false
        }

        return true
    }

    static func shouldStop(for signal: String, stopConditions: [String]) -> Bool {
        let normalizedSignal = signal.lowercased()
        return stopConditions.contains { condition in
            normalizedSignal.contains(condition.lowercased())
        }
    }
}

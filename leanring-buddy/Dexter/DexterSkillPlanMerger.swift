//
//  DexterSkillPlanMerger.swift
//  leanring-buddy
//

import Foundation

enum DexterSkillPlanMerger {
    static func merge(intentPlan: DexterIntentPlan?, skill: DexterSkill) -> DexterIntentPlan {
        let skillSteps: [DexterIntentPlanStep] = [
            DexterIntentPlanStep(order: 1, identifier: "skill_context", title: "Gather context required by skill \(skill.name)."),
            DexterIntentPlanStep(order: 2, identifier: "skill_intent", title: "Route intent through skill \(skill.id.rawValue)."),
            DexterIntentPlanStep(order: 3, identifier: "skill_plan", title: "Plan actions using skill capabilities."),
            DexterIntentPlanStep(order: 4, identifier: "skill_permission", title: "Confirm permissions for skill tools."),
            DexterIntentPlanStep(order: 5, identifier: "skill_execute", title: "Execute via tool gateway and agent runtime."),
            DexterIntentPlanStep(order: 6, identifier: "skill_verify", title: "Verify using \(skill.verification.policy)."),
            DexterIntentPlanStep(order: 7, identifier: "skill_memory", title: "Update memory per skill requirements."),
        ]

        guard let intentPlan else {
            return DexterIntentPlan(
                goal: skill.description,
                steps: skillSteps,
                requiredTools: skill.requiredCapabilities,
                requiredPermissions: skill.permissions,
                expectedStates: skill.verification.expectedStates,
                stopConditions: skill.verification.stopOnUncertainty
                    ? ["uncertainty", "verification_failed", "permission_denied"]
                    : ["verification_failed", "permission_denied"],
                actionBudget: 4,
                toolBudget: 6,
                timeoutSeconds: 120
            )
        }

        let mergedTools = Array(Set(intentPlan.requiredTools + skill.requiredCapabilities)).sorted()
        let mergedPermissions = Array(Set(intentPlan.requiredPermissions + skill.permissions)).sorted()
        let mergedStates = Array(Set(intentPlan.expectedStates + skill.verification.expectedStates)).sorted()

        return DexterIntentPlan(
            goal: "\(intentPlan.goal) [\(skill.name)]",
            steps: intentPlan.steps + skillSteps,
            requiredTools: mergedTools,
            requiredPermissions: mergedPermissions,
            expectedStates: mergedStates,
            stopConditions: intentPlan.stopConditions,
            actionBudget: max(intentPlan.actionBudget, 4),
            toolBudget: max(intentPlan.toolBudget, 6),
            timeoutSeconds: max(intentPlan.timeoutSeconds, 120)
        )
    }
}

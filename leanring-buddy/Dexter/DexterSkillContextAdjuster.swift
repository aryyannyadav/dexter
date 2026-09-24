//
//  DexterSkillContextAdjuster.swift
//  leanring-buddy
//

import Foundation

enum DexterSkillContextAdjuster {
    static func adjust(
        plan: DexterContextRelevancePlan,
        skill: DexterSkill?,
        context: DexterContext
    ) -> DexterContextRelevancePlan {
        guard let skill else { return plan }

        var adjustedPlan = plan

        if skill.memoryRequirements.includePersistentMemoryInContext {
            adjustedPlan.includePersistentMemory = true
        }

        if skill.memoryRequirements.includePersonalContextGraph {
            adjustedPlan.includePersonalContextGraph = true
        }

        if skill.memoryRequirements.includeCurrentTask {
            adjustedPlan.includeCurrentTask = true
        }

        if skill.requiredCapabilities.contains(where: { $0.hasPrefix("browser") }) {
            adjustedPlan.includeActiveApplication = true
            adjustedPlan.includeActiveWindow = true
        }

        if skill.id == .coding || skill.id == .study {
            adjustedPlan.includeScreenContext = adjustedPlan.includeScreenContext
                || context.screen.captureAvailability == .available
        }

        if skill.id == .fileOrganization {
            adjustedPlan.includeActiveApplication = true
        }

        return adjustedPlan
    }
}

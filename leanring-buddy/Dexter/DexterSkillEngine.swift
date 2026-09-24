//
//  DexterSkillEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterSkillEngine {
    static let defaultPipelinePhases: [DexterSkillPipelinePhase] = DexterSkillAutomationRuntime.canonicalPipelinePhases

    static func evaluate(
        userMessage: String,
        context: DexterContext,
        intentEngineResult: DexterIntentEngineResult
        // Context reserved for future skill routing (e.g. active app hints).
    ) -> DexterSkillEngineResult {
        _ = context

        let resolution = DexterSkillResolver.resolve(
            userMessage: userMessage,
            structuredIntent: intentEngineResult.structuredIntent
        )

        guard let resolution else {
            DexterSkillEngineLog.logNoMatch()
            return DexterSkillEngineResult(
                matchedSkill: nil,
                matchConfidence: 0,
                mergedIntentPlan: intentEngineResult.plan,
                pipelinePhases: defaultPipelinePhases
            )
        }

        DexterSkillEngineLog.logResolved(skill: resolution.skill, confidence: resolution.confidence)

        let mergedPlan = DexterSkillPlanMerger.merge(
            intentPlan: intentEngineResult.plan,
            skill: resolution.skill
        )

        return DexterSkillEngineResult(
            matchedSkill: resolution.skill,
            matchConfidence: resolution.confidence,
            mergedIntentPlan: mergedPlan,
            pipelinePhases: defaultPipelinePhases
        )
    }

    /// When a skill is attached with high confidence, intent clarification can be deferred to skill-specific prompts.
    static func shouldDeferIntentClarification(
        intentEngineResult: DexterIntentEngineResult,
        skillEngineResult: DexterSkillEngineResult
    ) -> Bool {
        guard let skill = skillEngineResult.matchedSkill else { return false }
        guard skillEngineResult.matchConfidence >= DexterSkillResolver.minimumConfidenceToAttachSkill else { return false }
        return intentEngineResult.requiresClarification && !skill.inputs.contains { $0.isRequired }
    }
}

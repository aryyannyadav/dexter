//
//  DexterSkillSystemTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterSkillSystemTests {
    @Test func catalogIncludesSevenInternalSkills() {
        let skills = DexterSkillCatalog.allSkills()
        #expect(skills.count == 7)
        let identifiers = Set(skills.map(\.id))
        #expect(identifiers == Set(DexterSkillIdentifier.allCases))
    }

    @Test func resolverMatchesDevelopmentEnvironmentTrigger() {
        let intent = DexterStructuredIntent(
            kind: .plan,
            target: .currentContext,
            confidence: 0.9,
            normalizedUserMessage: "prepare my coding environment"
        )
        let resolution = DexterSkillResolver.resolve(
            userMessage: "prepare my coding environment",
            structuredIntent: intent
        )
        #expect(resolution?.skill.id == .developmentEnvironment)
        #expect(resolution?.confidence ?? 0 >= 0.75)
        #expect(resolution?.skill.workflow.workflowIdentifier == DexterWorkflowCatalog.prepareCodingEnvironmentIdentifier)
    }

    @Test func planMergerAddsSkillCapabilities() {
        let skill = DexterSkillCatalog.skill(forIdentifier: .browserResearch)!
        let merged = DexterSkillPlanMerger.merge(intentPlan: nil, skill: skill)
        #expect(merged.requiredTools.contains("browser.proxy"))
        #expect(merged.expectedStates.contains("url_or_title_evidence"))
    }

    @Test func engineAttachesSkillAndPipelinePhases() {
        let intentResult = DexterIntentEngineResult(
            structuredIntent: DexterStructuredIntent(
                kind: .search,
                target: .freeText("swift concurrency"),
                confidence: 0.85,
                normalizedUserMessage: "search the web for swift concurrency"
            ),
            complexity: .simple,
            plan: nil,
            requiresClarification: false,
            clarificationPrompt: nil
        )

        let skillResult = DexterSkillEngine.evaluate(
            userMessage: "search the web for swift concurrency",
            context: DexterContext(userMessage: DexterUserMessageContext(text: "search the web for swift concurrency")),
            intentEngineResult: intentResult
        )

        #expect(skillResult.matchedSkill?.id == .browserResearch)
        #expect(skillResult.pipelinePhases.contains(.verify))
        #expect(skillResult.mergedIntentPlan != nil)
    }

    @Test func contextAdjusterEnablesPersonalGraphForProductivity() {
        let skill = DexterSkillCatalog.skill(forIdentifier: .productivity)!
        let basePlan = DexterContextRelevancePlan(
            includeActiveApplication: true,
            includeActiveWindow: false,
            includePointerContext: false,
            includeScreenContext: false,
            includeSelectedText: false,
            includeRecentConversationInPrompt: false,
            includeRecentConversationInAPIHistory: true,
            includeCurrentTask: false,
            includePersistentMemory: false,
            includePersonalContextGraph: false
        )

        let adjusted = DexterSkillContextAdjuster.adjust(
            plan: basePlan,
            skill: skill,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "catch me up"))
        )

        #expect(adjusted.includePersonalContextGraph)
        #expect(adjusted.includeCurrentTask)
        #expect(adjusted.includePersistentMemory)
    }
}

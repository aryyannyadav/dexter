//
//  DexterSkillResolver.swift
//  leanring-buddy
//

import Foundation

enum DexterSkillResolver {
    static let minimumConfidenceToAttachSkill = 0.45

    static func resolve(
        userMessage: String,
        structuredIntent: DexterStructuredIntent
    ) -> DexterSkillResolution? {
        let normalizedMessage = normalize(userMessage)
        var bestMatch: DexterSkillResolution?

        for skill in DexterSkillCatalog.allSkills() {
            let confidence = score(
                skill: skill,
                normalizedMessage: normalizedMessage,
                structuredIntent: structuredIntent
            )
            guard confidence >= minimumConfidenceToAttachSkill else { continue }

            if bestMatch == nil || confidence > bestMatch!.confidence {
                bestMatch = DexterSkillResolution(skill: skill, confidence: confidence)
            }
        }

        return bestMatch
    }

    private static func score(
        skill: DexterSkill,
        normalizedMessage: String,
        structuredIntent: DexterStructuredIntent
    ) -> Double {
        var confidence = 0.0

        for phrase in skill.trigger.phrases {
            let normalizedPhrase = normalize(phrase)
            if normalizedMessage == normalizedPhrase {
                confidence = max(confidence, 0.95)
            } else if normalizedMessage.contains(normalizedPhrase) {
                confidence = max(confidence, 0.75)
            }
        }

        if skill.trigger.alignedIntentKinds.contains(structuredIntent.kind) {
            confidence = max(confidence, 0.55)
        }

        if structuredIntent.confidence >= 0.8,
           skill.trigger.alignedIntentKinds.contains(structuredIntent.kind) {
            confidence += 0.1
        }

        if let workflowIdentifier = skill.workflow.workflowIdentifier,
           DexterWorkflowCatalog.workflowMatchingTrigger(userMessage: normalizedMessage)?.workflowIdentifier
            == workflowIdentifier {
            confidence = max(confidence, 0.9)
        }

        return min(confidence, 1.0)
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

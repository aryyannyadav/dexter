//
//  DexterIntentEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterIntentResponseModeMapper {
    static func responseMode(for intent: DexterStructuredIntent) -> DexterResponseMode {
        switch intent.kind {
        case .open, .close, .focus, .run:
            return .act
        case .fix:
            return intent.normalizedUserMessage == "fix it"
                || intent.normalizedUserMessage == "fix it for me"
                || intent.normalizedUserMessage == "apply the fix"
                ? .act
                : .troubleshoot
        case .teach:
            return .teach
        case .explain, .summarize, .compare, .find:
            return .explain
        case .search:
            return DexterBrowserIntelligencePlanner.isExecutableSearchUtterance(
                normalizedUserMessage: intent.normalizedUserMessage
            )
                ? .act
                : .guide
        case .plan, .automate, .edit, .create:
            return .guide
        case .remember, .forget, .remind, .ask, .companion:
            return .answer
        }
    }
}

enum DexterIntentClarificationPolicy {
    static func evaluate(intent: DexterStructuredIntent) -> (requiresClarification: Bool, prompt: String?) {
        if intent.confidence >= DexterIntentRouter.minimumConfidenceToActWithoutClarification {
            return (false, nil)
        }

        switch intent.kind {
        case .fix, .edit, .create, .run, .automate:
            return (
                true,
                "I'm not sure what you want me to change or run. Can you point at the target or describe the error more specifically?"
            )
        case .ask:
            return (
                true,
                "I didn't catch a clear request. What would you like Dexter to do?"
            )
        default:
            return (
                true,
                "I'm not fully confident I understood that. Could you rephrase what you want Dexter to do?"
            )
        }
    }
}

enum DexterIntentEngine {
    static func evaluate(userMessage: String, context: DexterContext?) -> DexterIntentEngineResult {
        let structuredIntent = DexterIntentRouter.recognize(userMessage: userMessage, context: context)
        let complexity = DexterIntentComplexityClassifier.classify(intent: structuredIntent)
        let clarification = DexterIntentClarificationPolicy.evaluate(intent: structuredIntent)

        let plan: DexterIntentPlan?
        if complexity == .complex,
           !clarification.requiresClarification,
           !DexterTrivialQuestionClassifier.isTrivialQuestion(userMessage) {
            plan = DexterPerformanceTiming.measureSync(bucket: .planning) {
                DexterIntentPlanner.plan(for: structuredIntent)
            }
            if let plan {
                DexterIntentEngineLog.logPlannerAttached(stepCount: plan.steps.count)
            }
        } else {
            plan = nil
        }

        DexterIntentEngineLog.logRouted(intent: structuredIntent, complexity: complexity)
        if clarification.requiresClarification {
            DexterIntentEngineLog.logClarificationRequested(reason: "confidence_below_threshold")
        }

        return DexterIntentEngineResult(
            structuredIntent: structuredIntent,
            complexity: complexity,
            plan: plan,
            requiresClarification: clarification.requiresClarification,
            clarificationPrompt: clarification.prompt
        )
    }
}

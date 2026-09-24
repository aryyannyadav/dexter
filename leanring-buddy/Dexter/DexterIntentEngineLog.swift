//
//  DexterIntentEngineLog.swift
//  leanring-buddy
//

import Foundation

enum DexterIntentEngineLog {
    static func logRouted(intent: DexterStructuredIntent, complexity: DexterIntentComplexity) {
        let targetDescription = intent.target.value ?? intent.target.reference.rawValue
        DexterTaskTraceRecorder.shared.markPhase(.intent)
        DexterObservabilityLog.intent(
            "intent=\(intent.kind.rawValue) target=\(targetDescription) confidence=\(String(format: "%.2f", intent.confidence)) complexity=\(complexity.rawValue)"
        )
    }

    static func logClarificationRequested(reason: String) {
        DexterObservabilityLog.intent("clarification_required reason=\(reason)")
    }

    static func logPlannerAttached(stepCount: Int) {
        DexterTaskTraceRecorder.shared.markPhase(.plan)
        DexterObservabilityLog.plan("planner_attached step_count=\(stepCount)")
    }
}

//
//  DexterContextEngineLog.swift
//  leanring-buddy
//

import Foundation

enum DexterContextEngineLog {
    static func logCollected(
        sectionName: String,
        relevanceLevel: DexterContextRelevanceLevel,
        priority: DexterContextPriority,
        detail: String
    ) {
        DexterTaskTraceRecorder.shared.markPhase(.context)
        DexterObservabilityLog.context(
            "collected section=\(sectionName) relevance=\(relevanceLevel.rawValue) priority=\(priority.rawValue) \(detail)"
        )
    }

    static func logSkipped(sectionName: String, reason: String) {
        DexterObservabilityLog.context("skipped section=\(sectionName) reason=\(reason)")
    }

    static func logSummary(diagnostics: DexterContextAssemblyDiagnostics) {
        let collectedNames = diagnostics.collectedSections.map(\.sectionName).joined(separator: ",")
        let skippedNames = diagnostics.skippedSections.map(\.sectionName).joined(separator: ",")
        DexterObservabilityLog.context("summary collected=[\(collectedNames)] skipped=[\(skippedNames)]")
    }
}
